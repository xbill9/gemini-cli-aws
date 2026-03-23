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

if [ -z "$SERVICE_EXISTS" ]; then
    echo "Creating new ECS Service..."
    # Note: This assumes default VPC and subnets. In a real scenario, you'd specify these.
    # We try to find the default VPC subnets.
    DEFAULT_VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --region ${AWS_REGION} --query "Vpcs[0].VpcId" --output text)
    SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${DEFAULT_VPC_ID}" --region ${AWS_REGION} --query "Subnets[*].SubnetId" --output text | tr '\t' ',')
    
    # Simple security group allowing 8080
    SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=default" "Name=vpc-id,Values=${DEFAULT_VPC_ID}" --region ${AWS_REGION} --query "SecurityGroups[0].GroupId" --output text)

    aws ecs create-service \
        --cluster ${CLUSTER_NAME} \
        --service-name ${SERVICE_NAME} \
        --task-definition ${TASK_FAMILY} \
        --desired-count 1 \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[${SUBNETS}],securityGroups=[${SG_ID}],assignPublicIp=ENABLED}" \
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
