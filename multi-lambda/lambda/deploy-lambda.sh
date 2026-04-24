#!/bin/bash
# lambda/deploy-lambda.sh - Deploy Multi-Agent System as a Stack to AWS Lambda

# Exit on error
set -e

# Source AWS credentials if they exist
if [ -f ".aws_creds" ]; then
    source ".aws_creds"
fi

# Default configurations
AWS_REGION=${AWS_REGION:-"us-east-1"}
SERVICE_PREFIX="course-creator"
STACK_NAME="${SERVICE_PREFIX}-stack"
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

# Create ECR repo for the stack if not exists
echo "Ensuring ECR repository ${STACK_NAME} exists..."
aws ecr describe-repositories --repository-names ${STACK_NAME} --region ${AWS_REGION} > /dev/null 2>&1 || \
    aws ecr create-repository --repository-name ${STACK_NAME} --region ${AWS_REGION}

FULL_IMAGE_NAME="${ECR_URL}/${STACK_NAME}:${IMAGE_TAG}"

# 1. Build and Push the Unified Image
echo "Building unified Docker image..."
docker build -t "${STACK_NAME}:${IMAGE_TAG}" .
docker tag "${STACK_NAME}:${IMAGE_TAG}" "${FULL_IMAGE_NAME}"
docker push "${FULL_IMAGE_NAME}"

# Function to deploy/update a Lambda from the stack image
deploy_lambda() {
    local func_name=$1
    local cmd=$2
    local timeout=$3
    local memory=$4
    local env_vars=$5

    echo "--- Deploying Lambda: ${func_name} ---"
    
    if aws lambda get-function --function-name ${func_name} --region ${AWS_REGION} > /dev/null 2>&1; then
        echo "Updating code for ${func_name}..."
        aws lambda update-function-code --region ${AWS_REGION} --function-name ${func_name} --image-uri ${FULL_IMAGE_NAME}
        aws lambda wait function-updated-v2 --function-name ${func_name} --region ${AWS_REGION}
        
        echo "Updating configuration for ${func_name}..."
        aws lambda update-function-configuration --region ${AWS_REGION} --function-name ${func_name} \
            --timeout ${timeout} --memory-size ${memory} \
            --image-config "Command=${cmd}" \
            --environment "Variables={${env_vars}}"
        
        # Ensure Function URL is BUFFERED
        aws lambda update-function-url-config --function-name ${func_name} \
            --region ${AWS_REGION} \
            --invoke-mode BUFFERED || true
        
        # Ensure permissions exist
        aws lambda add-permission --function-name ${func_name} \
            --region ${AWS_REGION} \
            --statement-id FunctionURLPublicAccess \
            --action lambda:InvokeFunctionUrl \
            --principal "*" \
            --function-url-auth-type NONE || true
        
        aws lambda add-permission --function-name ${func_name} \
            --region ${AWS_REGION} \
            --statement-id AllAccess \
            --action lambda:InvokeFunction \
            --principal "*" || true
    else
        echo "Creating new function ${func_name}..."
        aws lambda create-function --region ${AWS_REGION} \
            --function-name ${func_name} \
            --role ${LAMBDA_ROLE_ARN} \
            --package-type Image \
            --code ImageUri=${FULL_IMAGE_NAME} \
            --timeout ${timeout} \
            --memory-size ${memory} \
            --image-config "Command=${cmd}" \
            --environment "Variables={${env_vars}}"
        
        aws lambda wait function-active-v2 --function-name ${func_name} --region ${AWS_REGION}
        
        # Create Function URL
        aws lambda create-function-url-config --function-name ${func_name} \
            --region ${AWS_REGION} \
            --auth-type NONE \
            --invoke-mode BUFFERED
        
        # Add permissions
        aws lambda add-permission --function-name ${func_name} \
            --region ${AWS_REGION} \
            --statement-id FunctionURLPublicAccess \
            --action lambda:InvokeFunctionUrl \
            --principal "*" \
            --function-url-auth-type NONE
        
        aws lambda add-permission --function-name ${func_name} \
            --region ${AWS_REGION} \
            --statement-id AllAccess \
            --action lambda:InvokeFunction \
            --principal "*"
    fi
}

get_f_url() {
    aws lambda get-function-url-config --function-name $1 --region ${AWS_REGION} --query 'FunctionUrl' --output text
}

# 2. Deploy Sub-Agents
GEMINI_API_KEY=$(cat ${HOME}/gemini.key 2>/dev/null || echo "")
AGENT_ENV="GEMINI_API_KEY=${GEMINI_API_KEY},GOOGLE_API_KEY=${GEMINI_API_KEY},GENAI_MODEL=gemini-2.5-flash,LOG_LEVEL=INFO,GOOGLE_GENAI_USE_VERTEXAI=False"

deploy_lambda "${SERVICE_PREFIX}-researcher" '["python", "-m", "shared.adk_app", "--host", "0.0.0.0", "--port", "8080", "--a2a", "agents/researcher"]' 300 512 "${AGENT_ENV}"
RESEARCHER_URL=$(get_f_url "${SERVICE_PREFIX}-researcher")

deploy_lambda "${SERVICE_PREFIX}-judge" '["python", "-m", "shared.adk_app", "--host", "0.0.0.0", "--port", "8080", "--a2a", "agents/judge"]' 300 512 "${AGENT_ENV}"
JUDGE_URL=$(get_f_url "${SERVICE_PREFIX}-judge")

deploy_lambda "${SERVICE_PREFIX}-content-builder" '["python", "-m", "shared.adk_app", "--host", "0.0.0.0", "--port", "8080", "--a2a", "agents/content_builder"]' 300 512 "${AGENT_ENV}"
CONTENT_BUILDER_URL=$(get_f_url "${SERVICE_PREFIX}-content-builder")

# 3. Deploy Orchestrator
ORCH_ENV="RESEARCHER_AGENT_CARD_URL=${RESEARCHER_URL}a2a/researcher/.well-known/agent-card.json,JUDGE_AGENT_CARD_URL=${JUDGE_URL}a2a/judge/.well-known/agent-card.json,CONTENT_BUILDER_AGENT_CARD_URL=${CONTENT_BUILDER_URL}a2a/content_builder/.well-known/agent-card.json,GEMINI_API_KEY=${GEMINI_API_KEY},GOOGLE_API_KEY=${GEMINI_API_KEY},GENAI_MODEL=gemini-2.5-flash,GOOGLE_GENAI_USE_VERTEXAI=False"

deploy_lambda "${SERVICE_PREFIX}-orchestrator" '["python", "-m", "shared.adk_app", "--host", "0.0.0.0", "--port", "8080", "agents/orchestrator"]' 600 1024 "${ORCH_ENV}"
aws lambda update-function-url-config --function-name "${SERVICE_PREFIX}-orchestrator" --region ${AWS_REGION} --invoke-mode BUFFERED || true
ORCHESTRATOR_URL=$(get_f_url "${SERVICE_PREFIX}-orchestrator")

# 4. Deploy Course Builder Gateway (was 'app')
GATEWAY_ENV="AGENT_SERVER_URL=${ORCHESTRATOR_URL},AGENT_NAME=orchestrator,PORT=8080,AWS_LWA_READINESS_CHECK_TIMEOUT=30000,LOG_LEVEL=DEBUG"
deploy_lambda "${SERVICE_PREFIX}-course-builder" '["python", "app/main.py"]' 300 1024 "${GATEWAY_ENV}"

APP_URL=$(get_f_url "${SERVICE_PREFIX}-course-builder")

echo "--- Deployment Complete ---"
echo "Public Course Builder Gateway URL: ${APP_URL}"
