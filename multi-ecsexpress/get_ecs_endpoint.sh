#!/bin/bash
# get_ecs_endpoint.sh - Robustly fetch ECS Express Gateway endpoint

SVC=$1
REGION=${AWS_REGION:-"us-east-1"}
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

if [ -z "$SVC" ]; then
    echo "Usage: $0 <service-name>"
    exit 1
fi

# Try to get the ARN if only name is provided
SVC_ARN="arn:aws:ecs:$REGION:$ACCOUNT_ID:service/default/$SVC"

echo "Waiting for endpoint for $SVC..." >&2

for i in {1..30}; do
    ENDPOINT=$(aws ecs describe-express-gateway-service --service-arn "$SVC_ARN" --query 'service.activeConfigurations[0].ingressPaths[0].endpoint' --output text 2>/dev/null)
    
    if [ "$ENDPOINT" != "None" ] && [ -n "$ENDPOINT" ]; then
        echo "$ENDPOINT"
        exit 0
    fi
    sleep 5
done

echo "Timed out waiting for endpoint for $SVC" >&2
exit 1
