export AWS_PAGER :=
# Makefile for mcp-stdio-python

# Include and export AWS credentials if they exist
-include .aws_creds
export

# AWS Configuration
AWS_REGION ?= us-east-1
SERVICE_NAME ?= mcp-lambda-python-aws
IMAGE_NAME ?= mcp-lambda-image

# Derived AWS variables
AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text)
ECR_REPO_URL := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(SERVICE_NAME)
IMAGE_TAG := latest
FULL_IMAGE_NAME := $(ECR_REPO_URL):$(IMAGE_TAG)

# IAM Role for Lambda
LAMBDA_ROLE_NAME := McpLambdaExecutionRole
LAMBDA_ROLE_ARN := arn:aws:iam::$(AWS_ACCOUNT_ID):role/$(LAMBDA_ROLE_NAME)

.PHONY: all install run build test lint format type-check status git-status lambda-status endpoint pull push clean deploy docker-build ecr-create ecr-login push-ecr lambda-deploy iam-setup aws-destroy

all: install run

# Install dependencies
install:
	pip install -r requirements.txt

# Run the server locally
run:
	python main.py

# Target to show both git and Lambda status
status: lambda-status

# Target to show git status
git-status:
	@echo "Showing git status..."
	@git status

# Target to show AWS Lambda status
lambda-status:
	@aws lambda get-function --function-name $(SERVICE_NAME) --region $(AWS_REGION) --query 'Configuration.{Name:FunctionName, Status:State, LastModified:LastModified}' --output table 2>/dev/null || echo "Lambda function not found."

# Target to get the public endpoint URL (Lambda Function URL)
endpoint:
	@aws lambda get-function-url-config --function-name $(SERVICE_NAME) --region $(AWS_REGION) --query 'FunctionUrl' --output text

# Target to pull latest changes from git
pull:
	@echo "Pulling latest changes from git..."
	@git pull

# Target to push changes to git
push:
	@echo "Pushing changes to git..."
	@git push

# Code Quality targets
lint:
	@echo "Running flake8..."
	@flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics
	@flake8 . --count --exit-zero --max-complexity=10 --max-line-length=127 --statistics

format:
	@echo "Running black formatting..."
	@black . || echo "Black not installed, skipping."

# Build the Docker image
docker-build:
	@echo "Building the Docker image..."
	@docker buildx build --provenance=false -t $(IMAGE_NAME) .

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

# IAM Role setup for Lambda
iam-setup:
	@echo "Ensuring IAM role $(LAMBDA_ROLE_NAME) exists..."
	@aws iam get-role --role-name $(LAMBDA_ROLE_NAME) > /dev/null 2>&1 || \
		(echo "Creating role $(LAMBDA_ROLE_NAME)..." && \
		aws iam create-role --role-name $(LAMBDA_ROLE_NAME) \
			--assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' && \
		aws iam attach-role-policy --role-name $(LAMBDA_ROLE_NAME) \
			--policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole)

# Deploy to Amazon Lambda
deploy: lambda
lambda: iam-setup push-ecr create-lambda-function

create-lambda-function:
	@echo "Deploying to Lambda..."
	if aws lambda get-function --function-name $(SERVICE_NAME) --region $(AWS_REGION) > /dev/null 2>&1; then \
		echo "Updating existing Lambda function..."; \
		aws lambda update-function-code --region $(AWS_REGION) \
			--function-name $(SERVICE_NAME) \
			--image-uri $(FULL_IMAGE_NAME); \
		aws lambda update-function-configuration --region $(AWS_REGION) \
			--function-name $(SERVICE_NAME) \
			--timeout 300; \
		echo "Updating Function URL to BUFFERED mode (Stateless HTTP)..."; \
		aws lambda update-function-url-config --function-name $(SERVICE_NAME) \
			--region $(AWS_REGION) \
			--invoke-mode BUFFERED; \
	else \
		echo "Creating a new Lambda function..."; \
		aws lambda create-function --region $(AWS_REGION) \
			--function-name $(SERVICE_NAME) \
			--role $(LAMBDA_ROLE_ARN) \
			--package-type Image \
			--code ImageUri=$(FULL_IMAGE_NAME) \
			--timeout 300 \
			--memory-size 512; \
		echo "Waiting for function to be active..."; \
		aws lambda wait function-active-v2 --function-name $(SERVICE_NAME) --region $(AWS_REGION); \
		echo "Creating Function URL (BUFFERED mode for Stateless HTTP)..."; \
		aws lambda create-function-url-config --function-name $(SERVICE_NAME) \
			--region $(AWS_REGION) \
			--auth-type NONE \
			--invoke-mode BUFFERED; \
		echo "Adding permission for public URL access..."; \
		aws lambda add-permission --function-name $(SERVICE_NAME) \
			--region $(AWS_REGION) \
			--statement-id FunctionURLPublicAccess \
			--action lambda:InvokeFunctionUrl \
			--principal "*" \
			--function-url-auth-type NONE; \
	fi

aws-destroy:
	@echo "Destroying AWS resources for $(SERVICE_NAME)..."
	@echo "Deleting Lambda function..."
	@aws lambda delete-function --function-name $(SERVICE_NAME) --region $(AWS_REGION) 2>/dev/null || true
	@echo "Deleting ECR repository..."
	@aws ecr delete-repository --repository-name $(SERVICE_NAME) --region $(AWS_REGION) --force 2>/dev/null || true
	@echo "Deleting IAM role..."
	@aws iam detach-role-policy --role-name $(LAMBDA_ROLE_NAME) --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true
	@aws iam delete-role --role-name $(LAMBDA_ROLE_NAME) 2>/dev/null || true
	@echo "AWS resources destroyed."

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
