# Makefile for mcp-stdio-python

# Include and export AWS credentials if they exist
-include .aws_creds
export

# AWS Configuration
AWS_REGION ?= us-east-1
SERVICE_NAME ?= mcp-apprunner-python-aws
IMAGE_NAME ?= mcp-server-image

# Derived AWS variables
AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text)
ECR_REPO_URL := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(SERVICE_NAME)
IMAGE_TAG := latest
FULL_IMAGE_NAME := $(ECR_REPO_URL):$(IMAGE_TAG)

# IAM Role for App Runner ECR Access
APPRUNNER_ACCESS_ROLE_NAME := AppRunnerECRAccessRole
APPRUNNER_ACCESS_ROLE_ARN := arn:aws:iam::$(AWS_ACCOUNT_ID):role/$(APPRUNNER_ACCESS_ROLE_NAME)

.PHONY: all install run build test lint format type-check status git-status apprunner-status endpoint pull push clean deploy docker-build ecr-create ecr-login push-ecr create-apprunner-service iam-setup

all: install run

# Install dependencies
install:
	pip install -r requirements.txt

# Run the server locally
run:
	python main.py

# Target to show both git and App Runner status
status: apprunner-status

# Target to show git status
git-status:
	@echo "Showing git status..."
	@git status

# Target to show AWS App Runner status
apprunner-status:
	@echo "Checking AWS App Runner service status for $(SERVICE_NAME)..."
	@aws apprunner list-services --region $(AWS_REGION) \
		--query 'ServiceSummaryList[?ServiceName==`$(SERVICE_NAME)`].{Name:ServiceName, Status:Status, URL:ServiceUrl}' \
		--output table

# Target to get the public endpoint URL
endpoint:
	@aws apprunner list-services --region $(AWS_REGION) \
		--query 'ServiceSummaryList[?ServiceName==`$(SERVICE_NAME)`].ServiceUrl' \
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

# ECR related targets
ecr-create:
	@echo "Checking if ECR repository exists..."
	@aws ecr describe-repositories --repository-names $(SERVICE_NAME) --region $(AWS_REGION) > /dev/null 2>&1 || \
		(echo "Creating ECR repository $(SERVICE_NAME)..." && \
		aws ecr create-repository --repository-name $(SERVICE_NAME) --region $(AWS_REGION))

ecr-login:
	@echo "Logging in to Amazon ECR..."
	@aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

push-ecr: ecr-create ecr-login docker-build
	@echo "Pushing the Docker image to ECR..."
	@docker tag $(IMAGE_NAME) $(FULL_IMAGE_NAME)
	@docker push $(FULL_IMAGE_NAME)

# IAM Role setup for App Runner
iam-setup:
	@echo "Ensuring IAM role $(APPRUNNER_ACCESS_ROLE_NAME) exists..."
	@aws iam get-role --role-name $(APPRUNNER_ACCESS_ROLE_NAME) > /dev/null 2>&1 || \
		(echo "Creating role $(APPRUNNER_ACCESS_ROLE_NAME)..." && \
		aws iam create-role --role-name $(APPRUNNER_ACCESS_ROLE_NAME) \
			--assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"build.apprunner.amazonaws.com"},"Action":"sts:AssumeRole"}]}' && \
		aws iam attach-role-policy --role-name $(APPRUNNER_ACCESS_ROLE_NAME) \
			--policy-arn arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess)

# Deploy to Amazon App Runner
deploy: apprunner
apprunner: iam-setup push-ecr create-apprunner-service

create-apprunner-service:
	@echo "Deploying to App Runner..."
	@SERVICE_ARN=$$(aws apprunner list-services --region $(AWS_REGION) --query 'ServiceSummaryList[?ServiceName==`$(SERVICE_NAME)`].ServiceArn' --output text) && \
	if [ -z "$$SERVICE_ARN" ] || [ "$$SERVICE_ARN" = "None" ]; then \
		echo "Creating a new App Runner service..."; \
		aws apprunner create-service --region $(AWS_REGION) \
			--service-name $(SERVICE_NAME) \
			--source-configuration "{\"ImageRepository\":{\"ImageIdentifier\":\"$(FULL_IMAGE_NAME)\",\"ImageConfiguration\":{\"Port\":\"8080\"},\"ImageRepositoryType\":\"ECR\"},\"AuthenticationConfiguration\":{\"AccessRoleArn\":\"$(APPRUNNER_ACCESS_ROLE_ARN)\"}}" \
			--health-check-configuration "{\"Protocol\":\"HTTP\",\"Path\":\"/health\",\"Interval\":10,\"Timeout\":5,\"HealthyThreshold\":2,\"UnhealthyThreshold\":5}"; \
	else \
		echo "Updating existing App Runner service with ARN $$SERVICE_ARN..."; \
		aws apprunner update-service --region $(AWS_REGION) \
			--service-arn "$$SERVICE_ARN" \
			--source-configuration "{\"ImageRepository\":{\"ImageIdentifier\":\"$(FULL_IMAGE_NAME)\",\"ImageConfiguration\":{\"Port\":\"8080\"},\"ImageRepositoryType\":\"ECR\"},\"AuthenticationConfiguration\":{\"AccessRoleArn\":\"$(APPRUNNER_ACCESS_ROLE_ARN)\"}}" \
			--health-check-configuration "{\"Protocol\":\"HTTP\",\"Path\":\"/health\",\"Interval\":10,\"Timeout\":5,\"HealthyThreshold\":2,\"UnhealthyThreshold\":5}"; \
	fi

.PHONY: clean
clean:
	@echo "Cleaning up..."
	@find . -type f -name "*.pyc" -delete
	@find . -type d -name "__pycache__" -exec rm -rf {} +
	@find . -type d -name ".pyte*" -exec rm -rf {} +
	@find . -type d -name ".mypy*" -exec rm -rf {} +
	@rm -rf .venv

# Cloud Run (kept for reference)
cloudrun:
	@echo "Submitting build to Google Cloud Build..."
	@gcloud builds submit . --config cloudbuild.yaml
