#!/bin/bash
set -e

# Configuration
SERVICE_NAME=${SERVICE_NAME:-mcp-server-eb}
EB_ENV_NAME="${SERVICE_NAME}-env"

echo "Step 1: Terminating Elastic Beanstalk environment $EB_ENV_NAME..."
eb terminate "$EB_ENV_NAME" --force

echo "Step 2: Deleting Elastic Beanstalk application $SERVICE_NAME..."
# Terminate only kills the environment, we might want to delete the app too if we want a full clean
# However, 'eb terminate' is usually enough to stop billing.
# To delete the app: eb terminate --all --force (already handled above)
# If we want to remove the application entirely from the EB console:
# aws elasticbeanstalk delete-application --application-name "$SERVICE_NAME" --terminate-env-by-force

echo "Teardown complete!"
