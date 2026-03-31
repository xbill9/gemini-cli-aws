#!/bin/bash
# Configuration
SERVICE_NAME="biometric-scout-service"
IMAGE_NAME="biometric-scout-image"
AWS_REGION="us-east-1"

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

echo "Deploying to AWS ECS Express Mode..."
make deploy SERVICE_NAME=${SERVICE_NAME} IMAGE_NAME=${IMAGE_NAME} AWS_REGION=${AWS_REGION}
