#!/bin/bash
# Configuration for Fargate Deployment
SERVICE_NAME="biometric-scout-service"
CLUSTER_NAME="biometric-scout-cluster"
TASK_FAMILY="biometric-scout-task"
IMAGE_NAME="biometric-scout-image"
AWS_REGION="us-east-1"

# Environment variables
PROJECT_ID=$(cat ~/project_id.txt 2>/dev/null || echo "default-project")
GEMINI_API_KEY=$(cat ${HOME}/gemini.key 2>/dev/null || echo "${GOOGLE_API_KEY}")
GOOGLE_CLOUD_LOCATION="us-central1"

# Load AWS credentials if they exist
if [ -f .aws_creds ]; then
    echo "Loading AWS credentials from .aws_creds..."
    source .aws_creds
    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    if [ -n "$AWS_SESSION_TOKEN" ]; then
        export AWS_SESSION_TOKEN
    fi
fi

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ $? -ne 0 ]; then
    echo "Error: Failed to get AWS account ID. Please check your credentials."
    exit 1
fi

ECR_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${IMAGE_NAME}"

echo "Building frontend..."
cd frontend && npm install && npm run build && cd ..

echo "Building Docker image..."
docker build -t ${IMAGE_NAME}:latest .

echo "Ensuring ECR repository exists..."
aws ecr describe-repositories --repository-names ${IMAGE_NAME} --region ${AWS_REGION} || \
aws ecr create-repository --repository-name ${IMAGE_NAME} --region ${AWS_REGION}

echo "Authenticating to ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

echo "Pushing image to ECR..."
docker tag ${IMAGE_NAME}:latest ${ECR_REPO}:latest
docker push ${ECR_REPO}:latest

echo "Preparing Task Definition from template..."
sed -e "s/{{TASK_FAMILY}}/${TASK_FAMILY}/g" \
    -e "s/{{CONTAINER_NAME}}/${SERVICE_NAME}/g" \
    -e "s|{{ECR_URI}}|${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${IMAGE_NAME}|g" \
    -e "s/{{PROJECT_ID}}/${PROJECT_ID}/g" \
    -e "s/{{GEMINI_API_KEY}}/${GEMINI_API_KEY}/g" \
    -e "s/{{GOOGLE_CLOUD_LOCATION}}/${GOOGLE_CLOUD_LOCATION}/g" \
    -e "s/{{AWS_REGION}}/${AWS_REGION}/g" \
    -e "s/{{AWS_ACCOUNT_ID}}/${AWS_ACCOUNT_ID}/g" \
    task-definition.json.template > task-definition.json

echo "Registering new Task Definition..."
NEW_REVISION_ARN=$(aws ecs register-task-definition \
    --region ${AWS_REGION} \
    --cli-input-json file://task-definition.json \
    --query 'taskDefinition.taskDefinitionArn' --output text)

echo "Ensuring ECS Cluster exists..."
aws ecs describe-clusters --clusters ${CLUSTER_NAME} --region ${AWS_REGION} | grep -q "ACTIVE" || \
aws ecs create-cluster --cluster-name ${CLUSTER_NAME} --region ${AWS_REGION}

echo "Checking if ECS Service exists..."
SERVICE_EXISTS=$(aws ecs describe-services --cluster ${CLUSTER_NAME} --services ${SERVICE_NAME} --region ${AWS_REGION} --query 'services[?status==`ACTIVE`].serviceName' --output text)

# Networking Setup for ALB
DEFAULT_VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --region ${AWS_REGION} --query "Vpcs[0].VpcId" --output text)
SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${DEFAULT_VPC_ID}" --region ${AWS_REGION} --query "Subnets[*].SubnetId" --output text | tr '\t' ',')
SUBNET_1=$(echo ${SUBNETS} | cut -d',' -f1)
SUBNET_2=$(echo ${SUBNETS} | cut -d',' -f2)

# ALB Security Group
ALB_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=alb-sg" --region ${AWS_REGION} --query "SecurityGroups[0].GroupId" --output text)
if [ -z "$ALB_SG_ID" ] || [ "$ALB_SG_ID" == "None" ]; then
    ALB_SG_ID=$(aws ec2 create-security-group --group-name alb-sg --description "ALB HTTPS Security Group" --vpc-id ${DEFAULT_VPC_ID} --region ${AWS_REGION} --query "GroupId" --output text)
    aws ec2 authorize-security-group-ingress --group-id ${ALB_SG_ID} --protocol tcp --port 443 --cidr 0.0.0.0/0 --region ${AWS_REGION}
fi

# Task Security Group
TASK_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=fargate-task-sg" --region ${AWS_REGION} --query "SecurityGroups[0].GroupId" --output text)
if [ -z "$TASK_SG_ID" ] || [ "$TASK_SG_ID" == "None" ]; then
    TASK_SG_ID=$(aws ec2 create-security-group --group-name fargate-task-sg --description "Fargate Task Security Group" --vpc-id ${DEFAULT_VPC_ID} --region ${AWS_REGION} --query "GroupId" --output text)
    aws ec2 authorize-security-group-ingress --group-id ${TASK_SG_ID} --protocol tcp --port 8080 --source-group ${ALB_SG_ID} --region ${AWS_REGION}
fi

# Generate Self-Signed Cert for ALB
echo "Generating self-signed certificate..."
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=biometric-scout.fargate"
CERT_ARN=$(aws acm import-certificate --certificate fileb://cert.pem --private-key fileb://key.pem --region ${AWS_REGION} --query "CertificateArn" --output text)
rm key.pem cert.pem

# Create ALB
ALB_ARN=$(aws elbv2 describe-load-balancers --names biometric-scout-alb --region ${AWS_REGION} --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null)
if [ -z "$ALB_ARN" ] || [ "$ALB_ARN" == "None" ]; then
    ALB_ARN=$(aws elbv2 create-load-balancer --name biometric-scout-alb --subnets ${SUBNET_1} ${SUBNET_2} --security-groups ${ALB_SG_ID} --region ${AWS_REGION} --query "LoadBalancers[0].LoadBalancerArn" --output text)
fi

# Create Target Group
TG_ARN=$(aws elbv2 describe-target-groups --names biometric-scout-tg --region ${AWS_REGION} --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null)
if [ -z "$TG_ARN" ] || [ "$TG_ARN" == "None" ]; then
    TG_ARN=$(aws elbv2 create-target-group --name biometric-scout-tg --protocol HTTP --port 8080 --vpc-id ${DEFAULT_VPC_ID} --target-type ip --health-check-path /health --region ${AWS_REGION} --query "TargetGroups[0].TargetGroupArn" --output text)
fi

# Create HTTPS Listener
LISTENER_EXISTS=$(aws elbv2 describe-listeners --load-balancer-arn ${ALB_ARN} --region ${AWS_REGION} --query "Listeners[?Port==\`443\`].ListenerArn" --output text)
if [ -z "$LISTENER_EXISTS" ]; then
    aws elbv2 create-listener --load-balancer-arn ${ALB_ARN} --protocol HTTPS --port 443 --certificates CertificateArn=${CERT_ARN} --default-actions Type=forward,TargetGroupArn=${TG_ARN} --region ${AWS_REGION}
fi

# Check if existing service has a load balancer
HAS_LB=$(aws ecs describe-services --cluster ${CLUSTER_NAME} --services ${SERVICE_NAME} --region ${AWS_REGION} --query 'services[0].loadBalancers' --output text)

if [ -z "$SERVICE_EXISTS" ] || [ "$SERVICE_EXISTS" == "None" ]; then
    echo "Creating new ECS Service with ALB..."
    aws ecs create-service \
        --cluster ${CLUSTER_NAME} \
        --service-name ${SERVICE_NAME} \
        --task-definition ${TASK_FAMILY} \
        --desired-count 1 \
        --launch-type FARGATE \
        --load-balancers "targetGroupArn=${TG_ARN},containerName=${SERVICE_NAME},containerPort=8080" \
        --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_1},${SUBNET_2}],securityGroups=[${TASK_SG_ID}],assignPublicIp=ENABLED}" \
        --region ${AWS_REGION}
elif [ "$HAS_LB" == "[]" ] || [ -z "$HAS_LB" ]; then
    echo "Existing service found but no load balancer associated. Re-creating service to add ALB..."
    aws ecs delete-service --cluster ${CLUSTER_NAME} --service ${SERVICE_NAME} --force --region ${AWS_REGION}
    echo "Waiting for service to be deleted..."
    aws ecs wait services-inactive --cluster ${CLUSTER_NAME} --services ${SERVICE_NAME} --region ${AWS_REGION}
    
    aws ecs create-service \
        --cluster ${CLUSTER_NAME} \
        --service-name ${SERVICE_NAME} \
        --task-definition ${TASK_FAMILY} \
        --desired-count 1 \
        --launch-type FARGATE \
        --load-balancers "targetGroupArn=${TG_ARN},containerName=${SERVICE_NAME},containerPort=8080" \
        --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_1},${SUBNET_2}],securityGroups=[${TASK_SG_ID}],assignPublicIp=ENABLED}" \
        --region ${AWS_REGION}
else
    echo "Updating existing ECS Service to use new revision: ${NEW_REVISION_ARN}..."
    aws ecs update-service \
        --cluster ${CLUSTER_NAME} \
        --service ${SERVICE_NAME} \
        --task-definition ${NEW_REVISION_ARN} \
        --region ${AWS_REGION}
fi

echo "Fargate deployment initiated."
# rm task-definition.json
