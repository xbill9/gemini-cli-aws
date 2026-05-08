#!/bin/bash
# lightsail/deploy-lightsail.sh - Deploy Multi-Agent System to AWS Lightsail

# Exit on error
set -e

# Source AWS credentials
if [ -f ".aws_creds" ]; then
    source ".aws_creds"
    echo "AWS_ACCESS_KEY_ID is set to: ${AWS_ACCESS_KEY_ID}"
    echo "AWS_SECRET_ACCESS_KEY is set to: ${AWS_SECRET_ACCESS_KEY}"
    echo "AWS_SESSION_TOKEN is set to: ${AWS_SESSION_TOKEN}"
else
    echo "Error: .aws_creds file not found. Please run ./save-aws-creds.sh first."
    exit 1
fi

# Default configurations
AWS_REGION=${AWS_REGION:-"us-east-1"}
SERVICE_NAME="course-creator-service"
IMAGE_TAG="latest"

# 4. Create or Update Lightsail Service (Moved to before image push)
if ! AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN}" aws lightsail get-container-services --service-name ${SERVICE_NAME} > /dev/null 2>&1; then
    echo "Creating new Lightsail container service: ${SERVICE_NAME}"
    AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
    AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
    AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN}" \
    aws lightsail create-container-service --service-name ${SERVICE_NAME} --power small --scale 1
fi

# 5 Agents
AGENT_NAMES=("researcher" "judge" "content-builder" "orchestrator" "app")

# 1. Build and Push Docker Images to Lightsail
for name in "${AGENT_NAMES[@]}"; do
    DOCKERFILE_PATH=""
    if [ "$name" == "app" ]; then
        DOCKERFILE_PATH="app/Dockerfile"
        docker build --no-cache --network=host -t "$name:$IMAGE_TAG" -f "$DOCKERFILE_PATH" .
    else
        DOCKERFILE_PATH="agents/${name//-/_}/Dockerfile"
        docker build --no-cache -t "$name:$IMAGE_TAG" -f "$DOCKERFILE_PATH" .
    fi

    echo "Pushing image for $name to Lightsail..."
    AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
    AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
    AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN}" \
    aws lightsail push-container-image --service-name "$SERVICE_NAME" --label "$name" --image "$name:$IMAGE_TAG"
done

# 2. Get latest image names
RESEARCHER_IMAGE=$(AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN}" aws lightsail get-container-images --service-name ${SERVICE_NAME} | jq -r '.containerImages[] | select(.image | contains("researcher")) | .image' | head -n 1)
JUDGE_IMAGE=$(AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN}" aws lightsail get-container-images --service-name ${SERVICE_NAME} | jq -r '.containerImages[] | select(.image | contains("judge")) | .image' | head -n 1)
CONTENT_BUILDER_IMAGE=$(AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN}" aws lightsail get-container-images --service-name ${SERVICE_NAME} | jq -r '.containerImages[] | select(.image | contains("content-builder")) | .image' | head -n 1)
ORCHESTRATOR_IMAGE=$(AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN}" aws lightsail get-container-images --service-name ${SERVICE_NAME} | jq -r '.containerImages[] | select(.image | contains("orchestrator")) | .image' | head -n 1)
APP_IMAGE=$(AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN}" aws lightsail get-container-images --service-name ${SERVICE_NAME} | jq -r '.containerImages[] | select(.image | contains("app")) | .image' | head -n 1)

# 3. Create Deployment JSON
GEMINI_API_KEY=$(cat ${HOME}/gemini.key 2>/dev/null || echo "")

cat > lightsail/lightsail.json << EOL
{
    "containers": {
        "researcher": {
            "image": "${RESEARCHER_IMAGE}",
            "command": ["sh", "-c", "sleep 5; python3 -m shared.adk_app /app/agents/researcher --host 0.0.0.0 --port 8001 --a2a"],
            "ports": { "8001": "HTTP" },
            "environment": {
                "GEMINI_API_KEY": "${GEMINI_API_KEY}",
                "GENAI_MODEL": "gemini-2.5-flash"
            }
        },
        "judge": {
            "image": "${JUDGE_IMAGE}",
            "command": ["sh", "-c", "sleep 5; python3 -m shared.adk_app /app/agents/judge --host 0.0.0.0 --port 8002 --a2a"],
            "ports": { "8002": "HTTP" },
            "environment": {
                "GEMINI_API_KEY": "${GEMINI_API_KEY}",
                "GENAI_MODEL": "gemini-2.5-flash"
            }
        },
        "content-builder": {
            "image": "${CONTENT_BUILDER_IMAGE}",
            "command": ["sh", "-c", "sleep 5; python3 -m shared.adk_app /app/agents/content_builder --host 0.0.0.0 --port 8003 --a2a"],
            "ports": { "8003": "HTTP" },
            "environment": {
                "GEMINI_API_KEY": "${GEMINI_API_KEY}",
                "GENAI_MODEL": "gemini-2.5-flash"
            }
        },
        "orchestrator": {
            "image": "${ORCHESTRATOR_IMAGE}",
            "command": ["sh", "-c", "sleep 5; python3 -m shared.adk_app /app/agents/orchestrator --host 0.0.0.0 --port 8004 --a2a"],
            "ports": { "8004": "HTTP" },
            "environment": {
                "GEMINI_API_KEY": "${GEMINI_API_KEY}",
                "GENAI_MODEL": "gemini-2.5-flash",
                "RESEARCHER_AGENT_CARD_URL": "http://localhost:8001/a2a/researcher/.well-known/agent-card.json",
                "JUDGE_AGENT_CARD_URL": "http://localhost:8002/a2a/judge/.well-known/agent-card.json",
                "CONTENT_BUILDER_AGENT_CARD_URL": "http://localhost:8003/a2a/content_builder/.well-known/agent-card.json"
            }
        },
        "app": {
            "image": "${APP_IMAGE}",
            "ports": { "8000": "HTTP" },
            "environment": {
                "AGENT_SERVER_URL": "http://localhost:8004",
                "AGENT_NAME": "orchestrator",
                "PORT": "8000"
            }
        }
    },
    "publicEndpoint": {
        "containerName": "app",
        "containerPort": 8000,
        "healthCheck": {
            "healthyThreshold": 2,
            "unhealthyThreshold": 2,
            "timeoutSeconds": 15,
            "intervalSeconds": 20,
            "path": "/health",
            "successCodes": "200-499"
        }    }
}
EOL

# 4. Create or Update Lightsail Service
if ! AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN}" aws lightsail get-container-services --service-name ${SERVICE_NAME} > /dev/null 2>&1; then
    echo "Creating new Lightsail container service: ${SERVICE_NAME}"
    AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
    AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
    AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN}" \
    aws lightsail create-container-service --service-name ${SERVICE_NAME} --power small --scale 1
fi

echo "Deploying to Lightsail..."
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN}" \
aws lightsail create-container-service-deployment --service-name ${SERVICE_NAME} --cli-input-json file://lightsail/lightsail.json

echo "Deployment initiated. It may take a few minutes to complete."
echo "Check status with: make lightsail-status"
