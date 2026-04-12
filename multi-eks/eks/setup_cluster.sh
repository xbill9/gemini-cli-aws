#!/bin/bash
# eks/setup_cluster.sh - Set up/Check AWS EKS and ECR

# Exit on error
set -e

# Default configurations
AWS_REGION=${AWS_REGION:-"us-east-1"}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
EKS_CLUSTER_NAME=${EKS_CLUSTER_NAME:-"adk-eks-penguin"}

echo "=== AWS EKS Cluster Setup/Check ==="
echo "AWS Region:  $AWS_REGION"
echo "Account ID:  $AWS_ACCOUNT_ID"
echo "EKS Cluster: $EKS_CLUSTER_NAME"
echo "==================================="

# 1. Create ECR Repositories if they don't exist
ensure_ecr() {
    local name=$1
    echo "Checking ECR Repository $name..."
    if ! aws ecr describe-repositories --repository-names "$name" --region "$AWS_REGION" > /dev/null 2>&1; then
        echo "Creating ECR Repository $name..."
        aws ecr create-repository --repository-name "$name" --region "$AWS_REGION"
    else
        echo "ECR Repository $name already exists."
    fi
}

ensure_ecr "researcher"
ensure_ecr "judge"
ensure_ecr "content-builder"
ensure_ecr "orchestrator"
ensure_ecr "course-creator"

# 2. Check EKS Cluster
echo "Checking if EKS Cluster $EKS_CLUSTER_NAME exists and is ACTIVE..."
CLUSTER_STATUS=$(aws eks describe-cluster --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION" --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$CLUSTER_STATUS" != "ACTIVE" ]; then
    echo "Error: EKS Cluster $EKS_CLUSTER_NAME is $CLUSTER_STATUS. Please ensure it is ACTIVE."
    if [ "$CLUSTER_STATUS" == "NOT_FOUND" ]; then
        echo "Note: This script does not create the cluster automatically via CLI. Use eksctl or the AWS Console."
    fi
    exit 1
fi

# 3. Update Kubeconfig
echo "Updating kubeconfig for EKS Cluster $EKS_CLUSTER_NAME..."
aws eks update-kubeconfig --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION"

echo "EKS/ECR Setup Check Complete!"
