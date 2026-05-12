# Makefile for the Rust project (AWS Lambda Deployment)

export AWS_PAGER :=

# Include and export AWS credentials if they exist
-include .aws_creds
export

# AWS Configuration
AWS_REGION ?= us-east-1
SERVICE_NAME ?= mcp-lambda-rust-aws
IMAGE_NAME ?= mcp-lambda-image

# Derived AWS variables
AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text)
ECR_REPO_URL := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(SERVICE_NAME)
IMAGE_TAG := latest
FULL_IMAGE_NAME := $(ECR_REPO_URL):$(IMAGE_TAG)

# IAM Role for Lambda
LAMBDA_ROLE_NAME := McpLambdaExecutionRole
LAMBDA_ROLE_ARN := arn:aws:iam::$(AWS_ACCOUNT_ID):role/$(LAMBDA_ROLE_NAME)

.PHONY: all build run test fmt clippy check release status git-status lambda-status endpoint pull push clean deploy docker-build ecr-create ecr-login push-ecr lambda-deploy iam-setup aws-destroy

# The default target
all: build

# Build the project for development
build:
	@echo "Building the Rust project..."
	@cargo build

# Run the project locally
run:
	@echo "Running the Rust project..."
	@cargo run --release

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
	@aws lambda get-function-url-config --function-name $(SERVICE_NAME) --region $(AWS_REGION) --query 'FunctionUrl' --output text 2>/dev/null || echo "Function URL not configured."

# Target to pull latest changes from git
pull:
	@echo "Pulling latest changes from git..."
	@git pull

# Target to push changes to git
push:
	@echo "Pushing changes to git..."
	@git push

# Code Quality targets
test:
	@echo "Running tests..."
	@cargo test

fmt format:
	@echo "Formatting code..."
	@cargo fmt --all

clippy lint:
	@echo "Linting code..."
	@cargo clippy -- -D warnings

check:
	@echo "Checking the code..."
	@cargo check

release:
	@echo "Building Release..."
	@cargo build --release

# Build the Docker image
docker-build:
	@echo "Building the Docker image..."
	@docker buildx build --provenance=false -t $(IMAGE_NAME) .

# --- ECR Targets ---

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

# --- IAM Role setup for Lambda ---

iam-setup:
	@echo "Ensuring IAM role $(LAMBDA_ROLE_NAME) exists..."
	@aws iam get-role --role-name $(LAMBDA_ROLE_NAME) > /dev/null 2>&1 || \
		(echo "Creating role $(LAMBDA_ROLE_NAME)..." && \
		aws iam create-role --role-name $(LAMBDA_ROLE_NAME) \
			--assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}')
	@echo "Ensuring AWSLambdaBasicExecutionRole is attached..."
	@aws iam attach-role-policy --role-name $(LAMBDA_ROLE_NAME) \
		--policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# --- Lambda Deployment Targets ---

deploy: lambda

lambda: iam-setup push-ecr create-lambda-function

create-lambda-function:
	@echo "Deploying to Lambda..."
	if aws lambda get-function --function-name $(SERVICE_NAME) --region $(AWS_REGION) > /dev/null 2>&1; then \
		echo "Updating existing Lambda function..."; \
		aws lambda update-function-code --region $(AWS_REGION) \
			--function-name $(SERVICE_NAME) \
			--image-uri $(FULL_IMAGE_NAME); \
		aws lambda wait function-updated-v2 --function-name $(SERVICE_NAME) --region $(AWS_REGION); \
		aws lambda update-function-configuration --region $(AWS_REGION) \
			--function-name $(SERVICE_NAME) \
			--timeout 300 \
			--environment "Variables={ALLOWED_HOSTS=*}"; \
		echo "Updating Function URL to BUFFERED mode (Stateless HTTP)..."; \
		aws lambda update-function-url-config --function-name $(SERVICE_NAME) \
			--region $(AWS_REGION) \
			--auth-type NONE \
			--invoke-mode BUFFERED; \
		aws lambda add-permission --function-name $(SERVICE_NAME) \
			--region $(AWS_REGION) \
			--statement-id InvokeFunctionPublicUpdate \
			--action lambda:InvokeFunction \
			--principal "*" \
			--invoked-via-function-url 2>/dev/null || true; \
	else \
		echo "Creating a new Lambda function..."; \
		aws lambda create-function --region $(AWS_REGION) \
			--function-name $(SERVICE_NAME) \
			--role $(LAMBDA_ROLE_ARN) \
			--package-type Image \
			--code ImageUri=$(FULL_IMAGE_NAME) \
			--timeout 300 \
			--memory-size 512 \
			--environment "Variables={ALLOWED_HOSTS=*}"; \
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
		aws lambda add-permission --function-name $(SERVICE_NAME) \
			--region $(AWS_REGION) \
			--statement-id InvokeFunctionPublicUpdate \
			--action lambda:InvokeFunction \
			--principal "*" \
			--invoked-via-function-url; \
	fi

# --- Cleanup Targets ---

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

clean:
	@echo "Cleaning the project..."
	@cargo clean
	@rm -f server.pid server.log source.zip dist.zip
	@rm -rf dist/
