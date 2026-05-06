#!/bin/bash
# set -e  # Don't exit on error so we can clean up as much as possible

# Configuration
AWS_REGION=${AWS_REGION:-us-east-1}
SERVICE_NAME=${SERVICE_NAME:-mcp-lambda-python-aws}
STACK_NAME="${SERVICE_NAME}-infra"
CAPACITY_PROVIDER_NAME="${SERVICE_NAME}-cp"

echo "Step 1: Deleting Lambda function..."
aws lambda delete-function --function-name "$SERVICE_NAME" --region "$AWS_REGION" 2>/dev/null || echo "Lambda function already deleted or not found."

echo "Step 2: Deleting Capacity Provider..."
aws lambda delete-capacity-provider --capacity-provider-name "$CAPACITY_PROVIDER_NAME" --region "$AWS_REGION" 2>/dev/null || echo "Capacity Provider already deleted or not found."

echo "Step 3: Deleting CloudFormation Stack..."
aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$AWS_REGION"
echo "Waiting for stack deletion to complete (this may take a few minutes)..."
aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$AWS_REGION"

echo "Step 4: Deleting ECR repository (optional, keeping for now to avoid re-uploading everything)..."
# aws ecr delete-repository --repository-name "$SERVICE_NAME" --region "$AWS_REGION" --force 2>/dev/null || true

echo "Cleanup complete!"
