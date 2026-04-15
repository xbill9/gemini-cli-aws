#!/bin/bash
# deploy-ecsexpress.sh - Deploy Multi-Agent System to AWS ECS Express

# Exit on error
set -e

# Default configurations
AWS_REGION=${AWS_REGION:-"us-east-1"}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CLUSTER_NAME=${CLUSTER_NAME:-"adk-ecsexpress-cluster"}
SERVICE_NAME=${SERVICE_NAME:-"adk-ecsexpress-service"}
IMAGE_TAG=${IMAGE_TAG:-"latest"}

# Project Info
PROJECT_ID=$(cat ~/project_id.txt 2>/dev/null || echo "unknown-project")
GEMINI_API_KEY=$(cat ${HOME}/gemini.key 2>/dev/null || echo "")

# Derived AWS variables
ECR_LOGIN_SERVER="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
REPO_NAME="adk-course-creator"

echo "=== AWS ECS Express Deployment ==="
echo "AWS Region:  $AWS_REGION"
echo "Account ID:  $AWS_ACCOUNT_ID"
echo "Cluster:     $CLUSTER_NAME"
echo "Service:     $SERVICE_NAME"
echo "=============================="

# 1. Ensure ECR repository exists
echo "Checking ECR repository: $REPO_NAME..."
aws ecr describe-repositories --repository-names "$REPO_NAME" --region "$AWS_REGION" || \
    aws ecr create-repository --repository-name "$REPO_NAME" --region "$AWS_REGION"

# 2. Authenticate with ECR
echo "Logging in to Amazon ECR..."
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_LOGIN_SERVER"

# 3. Build and Push Docker Image (Monolith approach for now, or could push 5 images)
# For this version, let's assume we build the course-creator app which contains others
# and manages them via env vars if they were separate tasks, but here we'll push all 5 for ECS Express.

build_and_push() {
    local name=$1
    local dockerfile=$2
    local full_repo="${REPO_NAME}-${name}"
    local tag="${ECR_LOGIN_SERVER}/${full_repo}:${IMAGE_TAG}"
    
    echo "Checking ECR repository: ${full_repo}..."
    aws ecr describe-repositories --repository-names "${full_repo}" --region "$AWS_REGION" || \
        aws ecr create-repository --repository-name "${full_repo}" --region "$AWS_REGION"

    echo "Building $name..."
    docker build -t "$tag" -f "$dockerfile" .
    
    echo "Pushing $name..."
    docker push "$tag"
}

build_and_push "researcher" "agents/researcher/Dockerfile"
build_and_push "judge" "agents/judge/Dockerfile"
build_and_push "content-builder" "agents/content_builder/Dockerfile"
build_and_push "orchestrator" "agents/orchestrator/Dockerfile"
build_and_push "app" "app/Dockerfile"

# 4. ECS Express Service Creation Logic (Simplified)
# Note: This script assumes the ECS Cluster, Task Definitions, and Service already exist 
# or will be managed by a separate tool. For a full autonomous deploy, we'd need more infrastructure code.

echo "Deployment images pushed to ECR."
echo "Updating ECS service (if it exists) to trigger a new deployment..."
# This is a placeholder for actual service update/creation
# aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --force-new-deployment --region $AWS_REGION

echo "ECS Express deployment complete (images pushed)!"
