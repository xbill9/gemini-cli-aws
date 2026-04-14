#!/bin/bash
set -e

# Configuration
AWS_REGION="us-east-1"
CLUSTER_NAME="default"

# Load environment variables from .env if it exists
if [ -f .env ]; then
    echo "Loading environment variables from .env..."
    export $(grep -v '^#' .env | xargs)
fi

export GOOGLE_API_KEY="${GOOGLE_API_KEY:-}"
export GENAI_MODEL="${GENAI_MODEL:-gemini-2.5-flash}"

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text 2>/dev/null)
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

# 2. Deploy to ECS Express Mode
echo "Deploying to ECS Express Mode..."

# Function to get service endpoint, wait if needed
get_endpoint() {
    local service_name=$1
    local endpoint=""
    for i in {1..12}; do
        endpoint=$(aws ecs describe-express-gateway-service --service-arn arn:aws:ecs:${AWS_REGION}:${ACCOUNT_ID}:service/default/${service_name} --query 'service.endpoint' --output text 2>/dev/null || echo "")
        if [ -n "$endpoint" ] && [ "$endpoint" != "None" ] && [ "$endpoint" != "null" ] && [ "$endpoint" != "" ]; then
            echo "$endpoint"
            return 0
        fi
        >&2 echo "Waiting for endpoint for ${service_name} (attempt $i)..."
        sleep 5
    done
    echo "PENDING"
}

# Order matters: deps first
for SERVICE in researcher judge content-builder orchestrator app; do
    SERVICE_NAME=$SERVICE
    if [ "$SERVICE" == "app" ]; then SERVICE_NAME="course-creator"; fi
    
    echo "Deploying service: ${SERVICE_NAME}..."
    
    ECR_IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/ai-course-creator-${SERVICE}:latest"
    PORT=8000
    if [ "$SERVICE" == "app" ]; then PORT=8080; fi
    
    # Base environment variables
    ENV="[{name=GOOGLE_API_KEY,value=${GOOGLE_API_KEY}},{name=GENAI_MODEL,value=${GENAI_MODEL}}]"
    
    # Add dependency URLs for orchestrator
    if [ "$SERVICE" == "orchestrator" ]; then
        RESEARCHER_URL=$(get_endpoint "researcher")
        JUDGE_URL=$(get_endpoint "judge")
        CONTENT_BUILDER_URL=$(get_endpoint "content-builder")
        
        ENV="[{name=GOOGLE_API_KEY,value=${GOOGLE_API_KEY}},{name=GENAI_MODEL,value=${GENAI_MODEL}},{name=RESEARCHER_AGENT_CARD_URL,value=http://${RESEARCHER_URL}/a2a/researcher/.well-known/agent-card.json},{name=JUDGE_AGENT_CARD_URL,value=http://${JUDGE_URL}/a2a/judge/.well-known/agent-card.json},{name=CONTENT_BUILDER_AGENT_CARD_URL,value=http://${CONTENT_BUILDER_URL}/a2a/content_builder/.well-known/agent-card.json}]"
    fi
    
    # Add orchestrator URL for app
    if [ "$SERVICE" == "app" ]; then
        ORCHESTRATOR_URL=$(get_endpoint "orchestrator")
        ENV="[{name=GOOGLE_API_KEY,value=${GOOGLE_API_KEY}},{name=GENAI_MODEL,value=${GENAI_MODEL}},{name=AGENT_SERVER_URL,value=http://${ORCHESTRATOR_URL}},{name=AGENT_NAME,value=orchestrator}]"
    fi
    
    PRIMARY_CONTAINER="image=${ECR_IMAGE_URI},containerPort=${PORT},environment=${ENV}"
    
    if aws ecs describe-express-gateway-service --service-arn arn:aws:ecs:${AWS_REGION}:${ACCOUNT_ID}:service/default/${SERVICE_NAME} 2>/dev/null; then
        echo "Updating existing service ${SERVICE_NAME}..."
        aws ecs update-express-gateway-service \
            --service-arn arn:aws:ecs:${AWS_REGION}:${ACCOUNT_ID}:service/default/${SERVICE_NAME} \
            --primary-container "${PRIMARY_CONTAINER}" \
            --health-check-path /docs
    else
        echo "Creating new service ${SERVICE_NAME}..."
        aws ecs create-express-gateway-service \
            --service-name ${SERVICE_NAME} \
            --primary-container "${PRIMARY_CONTAINER}" \
            --execution-role-arn arn:aws:iam::${ACCOUNT_ID}:role/ecsTaskExecutionRole \
            --infrastructure-role-arn arn:aws:iam::${ACCOUNT_ID}:role/ecsInfrastructureRoleForExpressServices \
            --health-check-path /docs \
            --monitor-resources
    fi
done

echo "Deployment process completed!"
