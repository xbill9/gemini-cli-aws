#!/bin/bash
# lambda/deploy-lambda.sh - Deploy Multi-Agent System to AWS Lambda

# Exit on error
set -e

# Source AWS credentials if they exist
if [ -f ".aws_creds" ]; then
    source ".aws_creds"
fi

# Default configurations
AWS_REGION=${AWS_REGION:-"us-east-1"}
SERVICE_PREFIX="course-creator"
IMAGE_TAG="latest"

# Get Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# IAM Role for Lambda
LAMBDA_ROLE_NAME="McpLambdaExecutionRole"
LAMBDA_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${LAMBDA_ROLE_NAME}"

# Ensure IAM role exists
echo "Ensuring IAM role ${LAMBDA_ROLE_NAME} exists..."
if ! aws iam get-role --role-name ${LAMBDA_ROLE_NAME} > /dev/null 2>&1; then
    echo "Creating role ${LAMBDA_ROLE_NAME}..."
    aws iam create-role --role-name ${LAMBDA_ROLE_NAME} \
        --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
    aws iam attach-role-policy --role-name ${LAMBDA_ROLE_NAME} \
        --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
fi

# Login to ECR
echo "Logging in to Amazon ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URL}

# Agents to deploy
AGENT_NAMES=("researcher" "judge" "content-builder")
DECLARE_URLS=()

# 1. Deploy Sub-Agents
for name in "${AGENT_NAMES[@]}"; do
    REPO_NAME="${SERVICE_PREFIX}-${name}"
    FULL_IMAGE_NAME="${ECR_URL}/${REPO_NAME}:${IMAGE_TAG}"
    FUNCTION_NAME="${SERVICE_PREFIX}-${name}"

    echo "--- Deploying Sub-Agent: $name ---"
    
    # Create ECR repo if not exists
    aws ecr describe-repositories --repository-names ${REPO_NAME} --region ${AWS_REGION} > /dev/null 2>&1 || \
        aws ecr create-repository --repository-name ${REPO_NAME} --region ${AWS_REGION}

    # Build and Push
    DOCKERFILE_PATH="agents/${name//-/_}/Dockerfile"
    docker build -t "${REPO_NAME}:${IMAGE_TAG}" -f "${DOCKERFILE_PATH}" .
    docker tag "${REPO_NAME}:${IMAGE_TAG}" "${FULL_IMAGE_NAME}"
    docker push "${FULL_IMAGE_NAME}"

    # Create/Update Lambda
    if aws lambda get-function --function-name ${FUNCTION_NAME} --region ${AWS_REGION} > /dev/null 2>&1; then
        echo "Updating existing Lambda function ${FUNCTION_NAME}..."
        aws lambda update-function-code --region ${AWS_REGION} --function-name ${FUNCTION_NAME} --image-uri ${FULL_IMAGE_NAME}
        # Wait for update to complete
        aws lambda wait function-updated-v2 --function-name ${FUNCTION_NAME} --region ${AWS_REGION}
    else
        echo "Creating new Lambda function ${FUNCTION_NAME}..."
        aws lambda create-function --region ${AWS_REGION} \
            --function-name ${FUNCTION_NAME} \
            --role ${LAMBDA_ROLE_ARN} \
            --package-type Image \
            --code ImageUri=${FULL_IMAGE_NAME} \
            --timeout 300 \
            --memory-size 512
        aws lambda wait function-active-v2 --function-name ${FUNCTION_NAME} --region ${AWS_REGION}
        
        # Create Function URL
        aws lambda create-function-url-config --function-name ${FUNCTION_NAME} \
            --region ${AWS_REGION} \
            --auth-type NONE \
            --invoke-mode BUFFERED
        
        # Add permission
        aws lambda add-permission --function-name ${FUNCTION_NAME} \
            --region ${AWS_REGION} \
            --statement-id FunctionURLPublicAccess \
            --action lambda:InvokeFunctionUrl \
            --principal "*" \
            --function-url-auth-type NONE
    fi

    # Get Function URL
    F_URL=$(aws lambda get-function-url-config --function-name ${FUNCTION_NAME} --region ${AWS_REGION} --query 'FunctionUrl' --output text)
    echo "Sub-Agent $name URL: ${F_URL}"
    
    # Store URL for Orchestrator
    case $name in
        "researcher") RESEARCHER_URL="${F_URL}a2a/researcher/.well-known/agent-card.json" ;;
        "judge") JUDGE_URL="${F_URL}a2a/judge/.well-known/agent-card.json" ;;
        "content-builder") CONTENT_BUILDER_URL="${F_URL}a2a/content_builder/.well-known/agent-card.json" ;;
    esac
done

# 2. Deploy Orchestrator
NAME="orchestrator"
REPO_NAME="${SERVICE_PREFIX}-${NAME}"
FULL_IMAGE_NAME="${ECR_URL}/${REPO_NAME}:${IMAGE_TAG}"
FUNCTION_NAME="${SERVICE_PREFIX}-${NAME}"
GEMINI_API_KEY=$(cat ${HOME}/gemini.key 2>/dev/null || echo "")

echo "--- Deploying Orchestrator ---"

# Create ECR repo if not exists
aws ecr describe-repositories --repository-names ${REPO_NAME} --region ${AWS_REGION} > /dev/null 2>&1 || \
    aws ecr create-repository --repository-name ${REPO_NAME} --region ${AWS_REGION}

# Build and Push
docker build -t "${REPO_NAME}:${IMAGE_TAG}" -f "agents/orchestrator/Dockerfile" .
docker tag "${REPO_NAME}:${IMAGE_TAG}" "${FULL_IMAGE_NAME}"
docker push "${FULL_IMAGE_NAME}"

# Create/Update Lambda
if aws lambda get-function --function-name ${FUNCTION_NAME} --region ${AWS_REGION} > /dev/null 2>&1; then
    echo "Updating existing Orchestrator function..."
    aws lambda update-function-code --region ${AWS_REGION} --function-name ${FUNCTION_NAME} --image-uri ${FULL_IMAGE_NAME}
    aws lambda wait function-updated-v2 --function-name ${FUNCTION_NAME} --region ${AWS_REGION}
else
    echo "Creating new Orchestrator function..."
    aws lambda create-function --region ${AWS_REGION} \
        --function-name ${FUNCTION_NAME} \
        --role ${LAMBDA_ROLE_ARN} \
        --package-type Image \
        --code ImageUri=${FULL_IMAGE_NAME} \
        --timeout 600 \
        --memory-size 1024
    aws lambda wait function-active-v2 --function-name ${FUNCTION_NAME} --region ${AWS_REGION}
    aws lambda create-function-url-config --function-name ${FUNCTION_NAME} --region ${AWS_REGION} --auth-type NONE --invoke-mode BUFFERED
    aws lambda add-permission --function-name ${FUNCTION_NAME} --region ${AWS_REGION} --statement-id FunctionURLPublicAccess --action lambda:InvokeFunctionUrl --principal "*" --function-url-auth-type NONE
fi

# Update Environment Variables for Orchestrator
aws lambda update-function-configuration --region ${AWS_REGION} --function-name ${FUNCTION_NAME} \
    --environment "Variables={RESEARCHER_AGENT_CARD_URL=${RESEARCHER_URL},JUDGE_AGENT_CARD_URL=${JUDGE_URL},CONTENT_BUILDER_AGENT_CARD_URL=${CONTENT_BUILDER_URL},GEMINI_API_KEY=${GEMINI_API_KEY},GENAI_MODEL=gemini-2.5-flash}"

# Get Orchestrator URL
ORCHESTRATOR_URL=$(aws lambda get-function-url-config --function-name ${FUNCTION_NAME} --region ${AWS_REGION} --query 'FunctionUrl' --output text)
echo "Orchestrator URL: ${ORCHESTRATOR_URL}"

# 3. Deploy App
NAME="app"
REPO_NAME="${SERVICE_PREFIX}-${NAME}"
FULL_IMAGE_NAME="${ECR_URL}/${REPO_NAME}:${IMAGE_TAG}"
FUNCTION_NAME="${SERVICE_PREFIX}-${NAME}"

echo "--- Deploying App ---"

# Create ECR repo if not exists
aws ecr describe-repositories --repository-names ${REPO_NAME} --region ${AWS_REGION} > /dev/null 2>&1 || \
    aws ecr create-repository --repository-name ${REPO_NAME} --region ${AWS_REGION}

# Build and Push
docker build -t "${REPO_NAME}:${IMAGE_TAG}" -f "app/Dockerfile" .
docker tag "${REPO_NAME}:${IMAGE_TAG}" "${FULL_IMAGE_NAME}"
docker push "${FULL_IMAGE_NAME}"

# Create/Update Lambda
if aws lambda get-function --function-name ${FUNCTION_NAME} --region ${AWS_REGION} > /dev/null 2>&1; then
    echo "Updating existing App function..."
    aws lambda update-function-code --region ${AWS_REGION} --function-name ${FUNCTION_NAME} --image-uri ${FULL_IMAGE_NAME}
    aws lambda wait function-updated-v2 --function-name ${FUNCTION_NAME} --region ${AWS_REGION}
else
    echo "Creating new App function..."
    aws lambda create-function --region ${AWS_REGION} \
        --function-name ${FUNCTION_NAME} \
        --role ${LAMBDA_ROLE_ARN} \
        --package-type Image \
        --code ImageUri=${FULL_IMAGE_NAME} \
        --timeout 300 \
        --memory-size 512
    aws lambda wait function-active-v2 --function-name ${FUNCTION_NAME} --region ${AWS_REGION}
    aws lambda create-function-url-config --function-name ${FUNCTION_NAME} --region ${AWS_REGION} --auth-type NONE --invoke-mode BUFFERED
    aws lambda add-permission --function-name ${FUNCTION_NAME} --region ${AWS_REGION} --statement-id FunctionURLPublicAccess --action lambda:InvokeFunctionUrl --principal "*" --function-url-auth-type NONE
fi

# Update Environment Variables for App
aws lambda update-function-configuration --region ${AWS_REGION} --function-name ${FUNCTION_NAME} \
    --environment "Variables={AGENT_SERVER_URL=${ORCHESTRATOR_URL},AGENT_NAME=orchestrator,PORT=8080}"

APP_URL=$(aws lambda get-function-url-config --function-name ${FUNCTION_NAME} --region ${AWS_REGION} --query 'FunctionUrl' --output text)

echo "--- Deployment Complete ---"
echo "Public App URL: ${APP_URL}"
