#!/bin/bash
set -e

# Configuration
AWS_REGION=${AWS_REGION:-us-east-1}
SERVICE_NAME=${SERVICE_NAME:-mcp-server-eb}
EB_ENV_NAME="${SERVICE_NAME}-env"

echo "Step 0: Running Tests..."
make test

# EB CLI uses its own configuration folder .elasticbeanstalk
# We check if it's initialized, if not we initialize it.
if [ ! -d ".elasticbeanstalk" ]; then
    echo "Step 1: Initializing Elastic Beanstalk..."
    eb init "$SERVICE_NAME" --platform docker --region "$AWS_REGION"
fi

# Check if the environment exists
if ! eb status "$EB_ENV_NAME" > /dev/null 2>&1; then
    echo "Step 2: Creating Elastic Beanstalk environment $EB_ENV_NAME..."
    eb create "$EB_ENV_NAME" --platform docker --instance_type t3.micro --region "$AWS_REGION"
else
    echo "Step 2: Elastic Beanstalk environment $EB_ENV_NAME already exists."
fi

echo "Step 3: Deploying to Elastic Beanstalk..."
eb deploy "$EB_ENV_NAME"

echo "Step 4: Fetching Environment URL..."
EB_URL=$(eb status "$EB_ENV_NAME" | grep "CNAME" | awk '{print $2}')

echo "Deployment complete!"
echo "Environment URL: http://$EB_URL"
echo "MCP HTTP URL: http://$EB_URL/mcp"
echo "Health Check URL: http://$EB_URL/health"
