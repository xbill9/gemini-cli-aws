#!/bin/bash
# Configuration for Fargate Deployment
SERVICE_NAME="adk-fargate-service"
CLUSTER_NAME="adk-fargate-cluster"
TASK_FAMILY="adk-fargate-task"
IMAGE_NAME="adk-ui-image"
AWS_REGION="us-east-1"

# Environment from source if exists
PROJECT_ID=$(cat ~/project_id.txt 2>/dev/null || echo "comglitn")
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
ECR_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${IMAGE_NAME}"

echo "Building Docker image..."
docker build -t ${IMAGE_NAME}:latest .

echo "Authenticating to ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

echo "Pushing image to ECR..."
docker tag ${IMAGE_NAME}:latest ${ECR_REPO}:latest
docker push ${ECR_REPO}:latest

echo "Registering new Task Definition..."
# Fetch the current task definition as a template
TASK_DEFINITION=$(aws ecs describe-task-definition --task-definition ${TASK_FAMILY} --region ${AWS_REGION})

# Create a temporary file for the new container definition
# We only need the containerDefinitions, family, taskRoleArn, executionRoleArn, networkMode, requiresCompatibilities, cpu, and memory
NEW_TASK_DEF=$(echo $TASK_DEFINITION | jq '{
    containerDefinitions: .taskDefinition.containerDefinitions,
    family: .taskDefinition.family,
    taskRoleArn: .taskDefinition.taskRoleArn,
    executionRoleArn: .taskDefinition.executionRoleArn,
    networkMode: .taskDefinition.networkMode,
    requiresCompatibilities: .taskDefinition.requiresCompatibilities,
    cpu: .taskDefinition.cpu,
    memory: .taskDefinition.memory
}')

# Update the environment variables in the first container definition
NEW_TASK_DEF=$(echo $NEW_TASK_DEF | jq --arg PROJECT_ID "$PROJECT_ID" \
                                      --arg GEMINI_API_KEY "$GEMINI_API_KEY" \
                                      --arg IMAGE "$ECR_REPO:latest" \
    '.containerDefinitions[0].image = $IMAGE |
     .containerDefinitions[0].environment |= map(
        if .name == "GOOGLE_CLOUD_PROJECT" then .value = $PROJECT_ID
        elif .name == "GOOGLE_API_KEY" then .value = $GEMINI_API_KEY
        elif .name == "GEMINI_API_KEY" then .value = $GEMINI_API_KEY
        else . end
    )')

echo "$NEW_TASK_DEF" > new-task-def.json

NEW_REVISION=$(aws ecs register-task-definition \
    --region ${AWS_REGION} \
    --cli-input-json file://new-task-def.json \
    --query 'taskDefinition.taskDefinitionArn' --output text)

echo "Updating ECS Service to use new revision: ${NEW_REVISION}..."
aws ecs update-service \
    --cluster ${CLUSTER_NAME} \
    --service ${SERVICE_NAME} \
    --task-definition ${NEW_REVISION} \
    --region ${AWS_REGION}

echo "Fargate deployment initiated. It may take a few minutes for the new version to be fully operational."
rm new-task-def.json
