# Makefile for the Rust project

# Include and export AWS credentials if they exist
-include .aws_creds
export

export AWS_PAGER :=

# Variables
SERVICE_NAME := mcp-apprunner-rust-aws

# AWS Configuration
AWS_REGION ?= us-east-1
IMAGE_NAME ?= mcp-server-image

# Derived AWS variables
AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text)
ECR_REPO_URL := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(SERVICE_NAME)
IMAGE_TAG := latest
FULL_IMAGE_NAME := $(ECR_REPO_URL):$(IMAGE_TAG)

# IAM Role for App Runner ECR Access
APPRUNNER_ACCESS_ROLE_NAME := AppRunnerECRAccessRole
APPRUNNER_ACCESS_ROLE_ARN := arn:aws:iam::$(AWS_ACCOUNT_ID):role/$(APPRUNNER_ACCESS_ROLE_NAME)

.PHONY: all build run clean release test fmt clippy check docker-build deploy apprunner apprunner-status endpoint ecr-create ecr-login push-ecr iam-setup create-apprunner-service aws-destroy start stop status help

# The default target
all: build

# Build the project for development
build:
	@echo "Building the Rust project..."
	@cargo build

# Run the project
run:
	@echo "Running the Rust project..."
	@cargo run --release

# Start the server in the background
start: release
	@echo "Starting the MCP server..."
	@nohup ./target/release/$(SERVICE_NAME) > server.log 2>&1 & echo $$! > server.pid
	@echo "Server started with PID $$(cat server.pid)"

# Stop the background server
stop:
	@if [ -f server.pid ]; then \
		PID=$$(cat server.pid); \
		echo "Stopping $(SERVICE_NAME) (PID $$PID)..."; \
		kill $$PID || true; \
		rm server.pid; \
	else \
		echo "$(SERVICE_NAME) is not running."; \
	fi

# Get the status of the background server
status: apprunner-status
	@if [ -f server.pid ]; then \
		PID=$$(cat server.pid); \
		if ps -p $$PID > /dev/null; then \
			echo "$(SERVICE_NAME) is running locally (PID $$PID)."; \
		else \
			echo "$(SERVICE_NAME) PID file exists but process is not running."; \
			rm server.pid; \
		fi \
	else \
		echo "$(SERVICE_NAME) is not running locally."; \
	fi

# Clean the project
clean:
	@echo "Cleaning the project..."
	@cargo clean
	@rm -f server.pid server.log

# Build the project for release
release:
	@echo "Building Release..."
	@cargo build --release

# Run tests
test:
	@echo "Running tests..."
	@cargo test

# Format the code
fmt:
	@echo "Formatting code..."
	@cargo fmt --all -- --check

# Lint the code
clippy:
	@echo "Linting code..."
	@cargo clippy -- -D warnings

# Lint the code
lint:
	@echo "Linting code..."
	@cargo clippy -- -D warnings

# Check the code
check:
	@echo "Checking the code..."
	@cargo check

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
			--source-configuration "{\"ImageRepository\":{\"ImageIdentifier\":\"$(FULL_IMAGE_NAME)\",\"ImageConfiguration\":{\"Port\":\"8080\",\"RuntimeEnvironmentVariables\":{\"ALLOWED_HOSTS\":\"*\"}},\"ImageRepositoryType\":\"ECR\"},\"AuthenticationConfiguration\":{\"AccessRoleArn\":\"$(APPRUNNER_ACCESS_ROLE_ARN)\"}}" \
			--health-check-configuration "{\"Protocol\":\"HTTP\",\"Path\":\"/health\",\"Interval\":10,\"Timeout\":5,\"HealthyThreshold\":2,\"UnhealthyThreshold\":5}"; \
	else \
		echo "Updating existing App Runner service with ARN $$SERVICE_ARN..."; \
		aws apprunner update-service --region $(AWS_REGION) \
			--service-arn "$$SERVICE_ARN" \
			--source-configuration "{\"ImageRepository\":{\"ImageIdentifier\":\"$(FULL_IMAGE_NAME)\",\"ImageConfiguration\":{\"Port\":\"8080\",\"RuntimeEnvironmentVariables\":{\"ALLOWED_HOSTS\":\"*\"}},\"ImageRepositoryType\":\"ECR\"},\"AuthenticationConfiguration\":{\"AccessRoleArn\":\"$(APPRUNNER_ACCESS_ROLE_ARN)\"}}" \
			--health-check-configuration "{\"Protocol\":\"HTTP\",\"Path\":\"/health\",\"Interval\":10,\"Timeout\":5,\"HealthyThreshold\":2,\"UnhealthyThreshold\":5}"; \
	fi

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

aws-destroy:
	@echo "Destroying AWS resources for $(SERVICE_NAME)..."
	@SERVICE_ARN=$$(aws apprunner list-services --region $(AWS_REGION) --query 'ServiceSummaryList[?ServiceName==`$(SERVICE_NAME)`].ServiceArn' --output text) && \
	if [ -n "$$SERVICE_ARN" ] && [ "$$SERVICE_ARN" != "None" ]; then \
		echo "Deleting App Runner service $$SERVICE_ARN..."; \
		aws apprunner delete-service --service-arn "$$SERVICE_ARN" --region $(AWS_REGION) || true; \
	fi
	@echo "Deleting ECR repository $(SERVICE_NAME)..."
	@aws ecr delete-repository --repository-name $(SERVICE_NAME) --region $(AWS_REGION) --force 2>/dev/null || true
	@echo "AWS resources destroyed."

help:
	@echo "Makefile for the Rust project"
	@echo ""
	@echo "Usage:"
	@echo "    make <target>"
	@echo ""
	@echo "Targets:"
	@echo "    all              (default) same as 'build'"
	@echo "    build            Build the project for development"
	@echo "    run              Run the project"
	@echo "    start            Start the server in the background"
	@echo "    stop             Stop the background server"
	@echo "    status           Get the status of the background server"
	@echo "    clean            Clean the project"
	@echo "    release          Build the project for release"
	@echo "    test             Run tests"
	@echo "    fmt              Check formatting"
	@echo "    clippy           Lint the code"
	@echo "    check            Check the code"
	@echo "    docker-build     Build the Docker image"
	@echo "    deploy           Deploy to Amazon App Runner"
	@echo "    apprunner-status Check AWS App Runner service status"
	@echo "    endpoint         Get the public endpoint URL"
	@echo "    aws-destroy      Destroy AWS App Runner resources"
