#!/bin/bash
set -e

# Configuration
AWS_REGION="us-east-1"
CLUSTER_NAME="multi-agent-cluster"

# Load environment variables from .env if it exists
if [ -f .env ]; then
    echo "Loading environment variables from .env..."
    export $(grep -v '^#' .env | xargs)
fi

export GOOGLE_API_KEY="${GOOGLE_API_KEY:-}"

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text 2>/dev/null || echo "<AWS_ACCOUNT_ID>")

echo "AWS Account ID: ${ACCOUNT_ID}"

SERVICES=("researcher" "judge" "content-builder" "orchestrator" "app")

# 1. ECR Setup and Push
echo "Logging into ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com || echo "ECR login failed, skipping..."

for SERVICE in "${SERVICES[@]}"; do
    # Map service name to directory name
    DIR=$SERVICE
    if [ "$SERVICE" == "content-builder" ]; then DIR="content_builder"; fi
    
    REPO_NAME="ai-course-creator-${SERVICE}"
    echo "Processing service: ${SERVICE}..."
    
    # Ensure ECR repo exists
    aws ecr describe-repositories --repository-names ${REPO_NAME} --region ${AWS_REGION} 2>/dev/null || \
        aws ecr create-repository --repository-name ${REPO_NAME} --region ${AWS_REGION}
    
    ECR_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}"
    
    echo "Building image for ${SERVICE}..."
    if [ "$SERVICE" == "app" ]; then
        docker build --no-cache -t ${REPO_NAME} -f ./app/Dockerfile .
    else
        docker build --no-cache -t ${REPO_NAME} -f ./agents/${DIR}/Dockerfile .
    fi
    
    docker tag ${REPO_NAME}:latest ${ECR_URI}:latest
    docker push ${ECR_URI}:latest
done

# 2. Register Task Definitions and Update Services
echo "Registering task definitions..."

for SERVICE in "${SERVICES[@]}"; do
    TASK_DEF_FILE="ecs/task_definitions/${SERVICE//-/_}.json"
    if [ "$SERVICE" == "app" ]; then TASK_DEF_FILE="ecs/task_definitions/app.json"; fi
    
    echo "Registering task definition from ${TASK_DEF_FILE}..."
    
    # Replace placeholders in task definition
    TEMP_TASK_DEF="temp_task_def.json"
    sed -e "s|<AWS_ACCOUNT_ID>|${ACCOUNT_ID}|g" \
        -e "s|<REGION>|${AWS_REGION}|g" \
        -e "s|<GOOGLE_API_KEY>|${GOOGLE_API_KEY}|g" \
        ${TASK_DEF_FILE} > ${TEMP_TASK_DEF}
    
    # Register task definition
    REVISION=$(aws ecs register-task-definition --cli-input-json file://${TEMP_TASK_DEF} --region ${AWS_REGION} --query 'taskDefinition.taskDefinitionArn' --output text)
    echo "Registered revision: ${REVISION}"
    
    # Update service or create if not exists
    FAMILY=$(jq -r '.family' ${TEMP_TASK_DEF})
    echo "Updating service ${FAMILY} in cluster ${CLUSTER_NAME}..."
    
    # Check if service exists
    if aws ecs describe-services --cluster ${CLUSTER_NAME} --services ${FAMILY} --region ${AWS_REGION} --query 'services[0].status' --output text 2>/dev/null | grep -q "ACTIVE"; then
        aws ecs update-service --cluster ${CLUSTER_NAME} --service ${FAMILY} --task-definition ${FAMILY} --region ${AWS_REGION}
    else
        echo "Creating service ${FAMILY} in cluster ${CLUSTER_NAME}..."
        # Default subnets and security groups for creation
        SUBNETS="subnet-02282633641b9eeb1,subnet-0d15ef785c915ae8b"
        SECURITY_GROUPS="sg-0265341d16d95b029"
        
        aws ecs create-service \
            --cluster ${CLUSTER_NAME} \
            --service-name ${FAMILY} \
            --task-definition ${FAMILY} \
            --desired-count 1 \
            --launch-type FARGATE \
            --network-configuration "awsvpcConfiguration={subnets=[${SUBNETS}],securityGroups=[${SECURITY_GROUPS}],assignPublicIp=ENABLED}" \
            --region ${AWS_REGION}
    fi
    
    rm ${TEMP_TASK_DEF}
done

echo "Deployment process completed!"
