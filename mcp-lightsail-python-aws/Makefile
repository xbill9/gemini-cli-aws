export AWS_PAGER :=
# Makefile for mcp-stdio-python

# Include and export AWS credentials if they exist
-include .aws_creds
export

# AWS Lightsail Configuration
AWS_REGION ?= us-east-1
SERVICE_NAME ?= mcp-lightsail-python-aws
IMAGE_NAME ?= mcp-server-image

.PHONY: all install run build test lint format type-check status git-status lightsail-status endpoint pull push clean deploy docker-build push-lightsail create-deployment aws-destroy

# Target to show both git and Lightsail status
status:  lightsail-status

# Target to show git status
git-status:
	@echo "Showing git status..."
	@git status

# Target to show AWS Lightsail status
lightsail-status:
	@echo "Checking AWS Lightsail service status for $(SERVICE_NAME)..."
	@aws lightsail get-container-services --service-name $(SERVICE_NAME) --region $(AWS_REGION) \
		--query 'containerServices[0].{State:state, Power:power, Deployment:currentDeployment.state, URL:publicEndpoint.url}' \
		--output table

# Target to get the public endpoint URL
endpoint:
	@aws lightsail get-container-services --service-name $(SERVICE_NAME) --region $(AWS_REGION) \
		--query 'containerServices[0].url' \
		--output text

# Target to pull latest changes from git
pull:
	@echo "Pulling latest changes from git..."
	@git pull

# Target to push changes to git
push:
	@echo "Pushing changes to git..."
	@git push

# Build the Docker image
docker-build:
	@echo "Building the Docker image..."
	@docker build -t $(IMAGE_NAME) .

# cloud run
cloudrun:
	@echo "Submitting build to Google Cloud Build..."
	@gcloud builds submit . --config cloudbuild.yaml


# Deploy to Amazon Lightsail
deploy: lightsail
lightsail: docker-build push-lightsail create-deployment

push-lightsail:
	@echo "Pushing the Docker image to Lightsail..."
	@aws lightsail push-container-image --region $(AWS_REGION) --service-name $(SERVICE_NAME) --label $(IMAGE_NAME) --image $(IMAGE_NAME)

create-deployment:
	@echo "Creating a new deployment for Lightsail Container Service..."
	@IMAGE_IDENTIFIER=$$(aws lightsail get-container-images --service-name $(SERVICE_NAME) --query "containerImages[0].image" --output text) && \
	aws lightsail create-container-service-deployment --region $(AWS_REGION) \
		--service-name $(SERVICE_NAME) \
		--containers "{\"$(SERVICE_NAME)\":{\"image\":\"$$IMAGE_IDENTIFIER\",\"ports\":{\"8080\":\"HTTP\"}}}" \
		--public-endpoint "{\"containerName\":\"$(SERVICE_NAME)\",\"containerPort\":8080,\"healthCheck\":{\"path\":\"/health\"}}"

aws-destroy:
	@echo "Destroying AWS resources for $(SERVICE_NAME)..."
	@aws lightsail delete-container-service --service-name $(SERVICE_NAME) --region $(AWS_REGION) 2>/dev/null || true
	@echo "AWS resources destroyed."

.PHONY: clean
clean:
	@echo "Cleaning up..."
	@find . -type f -name "*.pyc" -delete
	@find . -type d -name "__pycache__" -exec rm -rf {} +
	@find . -type d -name ".pyte*" -exec rm -rf {} +
	@find . -type d -name ".mypy*" -exec rm -rf {} +
	@rm -rf .venv
