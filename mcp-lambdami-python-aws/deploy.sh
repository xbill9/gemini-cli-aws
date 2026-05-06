#!/bin/bash
set -e

# Configuration
AWS_REGION=${AWS_REGION:-us-east-1}
SERVICE_NAME=${SERVICE_NAME:-mcp-lambda-python-aws}
STACK_NAME="${SERVICE_NAME}-infra"
CAPACITY_PROVIDER_NAME="${SERVICE_NAME}-cp"

echo "Step 0: Running Tests..."
make test

echo "Step 1: Building and Pushing Docker Image to ECR..."
make push-ecr

echo "Step 2: Deploying CloudFormation Stack for Infrastructure..."
aws cloudformation deploy \
    --stack-name "$STACK_NAME" \
    --template-file template.yaml \
    --capabilities CAPABILITY_IAM \
    --region "$AWS_REGION"

# Get Outputs from CloudFormation
echo "Fetching infrastructure details..."
SUBNET_ID=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs[?OutputKey==`PrivateSubnetId`].OutputValue' --output text)
SECURITY_GROUP_ID=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs[?OutputKey==`SecurityGroupId`].OutputValue' --output text)
LAMBDA_ROLE_ARN=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs[?OutputKey==`LambdaRoleArn`].OutputValue' --output text)
OPERATOR_ROLE_ARN=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs[?OutputKey==`OperatorRoleArn`].OutputValue' --output text)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Step 3: Ensuring Capacity Provider exists..."
CP_ARN="arn:aws:lambda:${AWS_REGION}:${ACCOUNT_ID}:capacity-provider:${CAPACITY_PROVIDER_NAME}"

if ! aws lambda get-capacity-provider --capacity-provider-name "$CAPACITY_PROVIDER_NAME" --region "$AWS_REGION" > /dev/null 2>&1; then
    echo "Creating Capacity Provider $CAPACITY_PROVIDER_NAME..."
    aws lambda create-capacity-provider \
        --capacity-provider-name "$CAPACITY_PROVIDER_NAME" \
        --vpc-config "SubnetIds=[$SUBNET_ID],SecurityGroupIds=[$SECURITY_GROUP_ID]" \
        --permissions-config "CapacityProviderOperatorRoleArn=$OPERATOR_ROLE_ARN" \
        --instance-requirements "Architectures=[x86_64]" \
        --capacity-provider-scaling-config "MaxVCpuCount=30" \
        --region "$AWS_REGION"
else
    echo "Capacity Provider $CAPACITY_PROVIDER_NAME already exists."
    # Update logic could go here if needed, but create-capacity-provider doesn't have an 'update' equivalent in all cases easily
fi

echo "Step 4: Deploying Lambda Managed Instance function..."
# Get the ECR Image URI
ECR_REPO_URL="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${SERVICE_NAME}"
FULL_IMAGE_NAME="${ECR_REPO_URL}:latest"

# Check if function exists and its capacity provider config
EXISTING_CONFIG=$(aws lambda get-function --function-name "$SERVICE_NAME" --region "$AWS_REGION" --query 'Configuration.CapacityProviderConfig' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$EXISTING_CONFIG" != "NOT_FOUND" ] && [ "$EXISTING_CONFIG" != "None" ]; then
    echo "Updating existing Managed Instances function..."
    aws lambda update-function-code \
        --function-name "$SERVICE_NAME" \
        --image-uri "$FULL_IMAGE_NAME" \
        --region "$AWS_REGION"
    
    # Wait for update to complete
    aws lambda wait function-updated-v2 --function-name "$SERVICE_NAME" --region "$AWS_REGION"
elif [ "$EXISTING_CONFIG" != "NOT_FOUND" ]; then
    echo "Deleting existing standard Lambda function to recreate as Managed Instance..."
    aws lambda delete-function --function-name "$SERVICE_NAME" --region "$AWS_REGION"
    aws lambda wait function-deleted-v2 --function-name "$SERVICE_NAME" --region "$AWS_REGION" 2>/dev/null || sleep 10
fi

if [ "$EXISTING_CONFIG" == "NOT_FOUND" ] || [ "$EXISTING_CONFIG" == "None" ]; then
    echo "Creating new Lambda Managed Instance function..."
    aws lambda create-function \
        --function-name "$SERVICE_NAME" \
        --package-type Image \
        --code ImageUri="$FULL_IMAGE_NAME" \
        --role "$LAMBDA_ROLE_ARN" \
        --timeout 300 \
        --memory-size 2048 \
        --architectures x86_64 \
        --capacity-provider-config "LambdaManagedInstancesCapacityProviderConfig={CapacityProviderArn=$CP_ARN}" \
        --region "$AWS_REGION"
    
    echo "Waiting for function to be ready (Active or ActiveNonInvocable)..."
    for i in {1..30}; do
        STATE=$(aws lambda get-function --function-name "$SERVICE_NAME" --region "$AWS_REGION" --query 'Configuration.State' --output text)
        echo "Current state: $STATE"
        if [ "$STATE" == "Active" ] || [ "$STATE" == "ActiveNonInvocable" ]; then
            break
        fi
        sleep 10
    done
fi

echo "Step 5: Publishing Function Version..."
VERSION=$(aws lambda publish-version --function-name "$SERVICE_NAME" --region "$AWS_REGION" --query 'Version' --output text)
echo "Published version: $VERSION"

echo "Waiting for version $VERSION to be Active..."
for i in {1..30}; do
    V_STATE=$(aws lambda get-function --function-name "$SERVICE_NAME:$VERSION" --region "$AWS_REGION" --query 'Configuration.State' --output text)
    echo "Version $VERSION state: $V_STATE"
    if [ "$V_STATE" == "Active" ]; then
        break
    fi
    sleep 10
done

echo "Step 6: Updating 'prod' alias to version $VERSION..."
if aws lambda get-alias --function-name "$SERVICE_NAME" --name prod --region "$AWS_REGION" > /dev/null 2>&1; then
    aws lambda update-alias --function-name "$SERVICE_NAME" --name prod --function-version "$VERSION" --region "$AWS_REGION"
else
    aws lambda create-alias --function-name "$SERVICE_NAME" --name prod --function-version "$VERSION" --region "$AWS_REGION"
fi

echo "Step 7: Publishing to LATEST.PUBLISHED for Managed Instances support..."
aws lambda publish-version --function-name "$SERVICE_NAME" --publish-to LATEST_PUBLISHED --region "$AWS_REGION" > /dev/null

echo "Step 8: Finalizing API Gateway..."
# Wait for the Lambda alias and permissions to be ready
sleep 5

API_ENDPOINT=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' --output text)

echo "Deployment complete!"
echo "API Endpoint URL: $API_ENDPOINT"
echo "MCP HTTP URL: $API_ENDPOINT/mcp"
echo "Health Check URL: $API_ENDPOINT/health"
