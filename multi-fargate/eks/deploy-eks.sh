#!/bin/bash
# eks/deploy-eks.sh - Deploy Multi-Agent System to AWS EKS

# Exit on error
set -e

# Default configurations
AWS_REGION=${AWS_REGION:-"us-east-1"}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
EKS_CLUSTER_NAME=${EKS_CLUSTER_NAME:-"adk-eks-penguin"}
IMAGE_TAG=${IMAGE_TAG:-"latest"}

# Project Info
PROJECT_ID=$(cat ~/project_id.txt 2>/dev/null || echo "unknown-project")
GEMINI_API_KEY=$(cat ${HOME}/gemini.key 2>/dev/null || echo "")

# Derived AWS variables
ECR_LOGIN_SERVER="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "=== AWS EKS Deployment ==="
echo "AWS Region:  $AWS_REGION"
echo "Account ID:  $AWS_ACCOUNT_ID"
echo "EKS Cluster: $EKS_CLUSTER_NAME"
echo "=========================="

# 1. Ensure ECR repos and EKS connection
./eks/setup_cluster.sh

# 2. Authenticate with ECR
echo "Logging in to Amazon ECR..."
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_LOGIN_SERVER"

# 3. Build and Push Docker Images
build_and_push() {
    local name=$1
    local dockerfile=$2
    local tag="${ECR_LOGIN_SERVER}/${name}:${IMAGE_TAG}"
    
    echo "Building $name..."
    docker build -t "$tag" -f "$dockerfile" .
    
    echo "Pushing $name..."
    docker push "$tag"
}

build_and_push "researcher" "agents/researcher/Dockerfile"
build_and_push "judge" "agents/judge/Dockerfile"
build_and_push "content-builder" "agents/content_builder/Dockerfile"
build_and_push "orchestrator" "agents/orchestrator/Dockerfile"
build_and_push "course-creator" "app/Dockerfile"

# 4. Create Secrets in Kubernetes
echo "Creating/Updating adk-secrets in Kubernetes..."
kubectl create secret generic adk-secrets \
    --from-literal=GOOGLE_API_KEY="$GEMINI_API_KEY" \
    --dry-run=client -o yaml | kubectl apply -f -

# 5. Deploy to EKS
echo "Deploying to AWS EKS..."
# Use sed to replace variables in manifests.yaml
sed -e "s|\${ECR_LOGIN_SERVER}|$ECR_LOGIN_SERVER|g" \
    -e "s|\${IMAGE_TAG}|$IMAGE_TAG|g" \
    -e "s|\${PROJECT_ID}|$PROJECT_ID|g" \
    eks/manifests.yaml | kubectl apply -f -

echo "Waiting for deployments to complete..."
kubectl rollout status deployment/researcher
kubectl rollout status deployment/judge
kubectl rollout status deployment/content-builder
kubectl rollout status deployment/orchestrator
kubectl rollout status deployment/course-creator

echo "Deployment complete!"
echo "Course Creator External URL (may take a moment to appear):"
kubectl get svc course-creator -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo ""
