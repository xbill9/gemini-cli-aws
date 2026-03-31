#!/bin/bash
set -e

# Configuration
SERVICE_NAME="biometric-scout-service"
IMAGE_NAME="biometric-scout-image"
AWS_REGION="us-east-1"
CLUSTER_NAME="biometric-scout-cluster"
ECR_REPO_NAME="biometric-scout-repo"

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

# Load environment variables from .env if it exists
if [ -f .env ]; then
    echo "Loading environment variables from .env..."
    # Export variables from .env, handling potential quotes
    export $(grep -v '^#' .env | xargs)
fi

# Ensure GOOGLE_CLOUD_PROJECT and other vars are set (fallbacks if needed)
export GOOGLE_CLOUD_PROJECT="${GOOGLE_CLOUD_PROJECT:-your-project-id}"
export GOOGLE_CLOUD_LOCATION="${GOOGLE_CLOUD_LOCATION:-us-central1}"
export GOOGLE_GENAI_USE_VERTEXAI="${GOOGLE_GENAI_USE_VERTEXAI:-True}"
export MODEL_ID="${MODEL_ID:-gemini-live-2.5-flash-native-audio}"
export GOOGLE_API_KEY="${GOOGLE_API_KEY:-}"

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
ECR_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"

echo "Using ECR URI: ${ECR_URI}"

# 1. ECR Setup
echo "Ensuring ECR repository exists..."
aws ecr describe-repositories --repository-names ${ECR_REPO_NAME} 2>/dev/null || \
    aws ecr create-repository --repository-name ${ECR_REPO_NAME}

# 2. ECR Login
echo "Logging into ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# 3. Build and Push Image
echo "Building and pushing image to ECR..."
docker build -t ${IMAGE_NAME} .
docker tag ${IMAGE_NAME} ${ECR_URI}:latest
docker push ${ECR_URI}:latest

# 4. Check/Create EKS Cluster
echo "Checking for EKS cluster: ${CLUSTER_NAME}..."
if ! eksctl get cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} > /dev/null 2>&1; then
    echo "Cluster not found. Creating EKS cluster (this may take 15-20 minutes)..."
    eksctl create cluster -f eks-cluster.yaml
else
    echo "EKS cluster ${CLUSTER_NAME} already exists."
    # Ensure kubeconfig is updated
    aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}
fi

# 5. Prepare and Apply Kubernetes Manifests
echo "Preparing Kubernetes deployment manifest..."
sed -e "s|{{IMAGE_NAME}}|${IMAGE_NAME}|g" \
    -e "s|{{ECR_URI}}|${ECR_URI}|g" \
    -e "s|{{GOOGLE_CLOUD_PROJECT}}|${GOOGLE_CLOUD_PROJECT}|g" \
    -e "s|{{GOOGLE_CLOUD_LOCATION}}|${GOOGLE_CLOUD_LOCATION}|g" \
    -e "s|{{GOOGLE_GENAI_USE_VERTEXAI}}|${GOOGLE_GENAI_USE_VERTEXAI}|g" \
    -e "s|{{GOOGLE_API_KEY}}|${GOOGLE_API_KEY}|g" \
    -e "s|{{MODEL_ID}}|${MODEL_ID}|g" \
    k8s-deployment.yaml.template > k8s-deployment.yaml

echo "Applying Kubernetes manifests..."
kubectl apply -f k8s-deployment.yaml

echo "Deployment complete!"
echo "You can check the status with: kubectl get pods,svc"
echo "Wait for the LoadBalancer URL to be active: kubectl get svc ${IMAGE_NAME}-service"
