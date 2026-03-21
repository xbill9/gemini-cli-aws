#!/bin/bash
# Configuration
SERVICE_NAME="biometric-scout-service"
IMAGE_NAME="biometric-scout-image"
AWS_REGION="us-east-1"
PROJECT_ID=$(cat ~/project_id.txt) # For Vertex AI
GOOGLE_CLOUD_LOCATION="us-central1"
GEMINI_API_KEY=$(cat ${HOME}/gemini.key)

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

echo "Building Docker image..."
docker build -t ${IMAGE_NAME} .

echo "Pushing Docker image to Amazon Lightsail..."
aws lightsail push-container-image \
    --region ${AWS_REGION} \
    --service-name ${SERVICE_NAME} \
    --label ${IMAGE_NAME} \
    --image ${IMAGE_NAME}

echo "Getting image identifier..."
IMAGE_IDENTIFIER=$(aws lightsail get-container-images \
    --service-name ${SERVICE_NAME} \
    --region ${AWS_REGION} \
    --query "containerImages[0].image" \
    --output text)

echo "Creating deployment for Lightsail Container Service..."
aws lightsail create-container-service-deployment \
    --region ${AWS_REGION} \
    --service-name ${SERVICE_NAME} \
    --containers "{
        \"${SERVICE_NAME}\": {
            \"image\": \"${IMAGE_IDENTIFIER}\",
            \"ports\": {
                \"8080\": \"HTTP\"
            },
            \"environment\": {
                \"GOOGLE_CLOUD_PROJECT\": \"${PROJECT_ID}\",
                \"GOOGLE_CLOUD_LOCATION\": \"${GOOGLE_CLOUD_LOCATION}\",
                \"GOOGLE_GENAI_USE_VERTEXAI\": \"False\",
                \"VERTEX_AI\": \"FALSE\",
                \"VERTEX\": \"no\",
                \"GOOGLE_API_KEY\": \"${GEMINI_API_KEY}\",
                \"MODEL_ID\": \"gemini-2.5-flash-native-audio-preview-12-2025\"
            }
        }
    }" \
    --public-endpoint "{
        \"containerName\": \"${SERVICE_NAME}\",
        \"containerPort\": 8080,
        \"healthCheck\": {
            \"path\": \"/\",
            \"successCodes\": \"200-499\"
        }
    }"

echo "Deployment complete."
