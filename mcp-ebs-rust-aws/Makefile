# Makefile for the Rust project

# Include and export AWS credentials if they exist
-include .aws_creds
export

export AWS_PAGER :=

# Variables
SERVICE_NAME := mcp-ebs-rust-aws
IMAGE_NAME := mcp-server-image

# AWS Elastic Beanstalk Configuration
AWS_REGION ?= us-east-1
EB_APP_NAME ?= $(SERVICE_NAME)
EB_ENV_NAME ?= $(SERVICE_NAME)-env
# Try to find an existing EB S3 bucket, otherwise it will be created in eb-init
S3_BUCKET ?= $(shell aws s3 ls 2>/dev/null | grep elasticbeanstalk-$(AWS_REGION) | awk '{print $$3}' | head -n 1)
EB_SOLUTION_STACK ?= 64bit Amazon Linux 2023 v4.12.3 running Docker

.PHONY: all build run clean release test fmt clippy check docker-build deploy eb-init eb-package eb-deploy eb-status eb-endpoint start stop status help aws-destroy

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
status:
	@if [ -f server.pid ]; then \
		PID=$$(cat server.pid); \
		if ps -p $$PID > /dev/null; then \
			echo "$(SERVICE_NAME) is running (PID $$PID)."; \
		else \
			echo "$(SERVICE_NAME) PID file exists but process is not running."; \
			rm server.pid; \
		fi \
	else \
		echo "$(SERVICE_NAME) is not running."; \
	fi

# Clean the project
clean:
	@echo "Cleaning the project..."
	@cargo clean
	@rm -f server.pid server.log source.zip

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

# Build the Docker image (optional for EB if using source bundle)
docker-build:
	@echo "Building the Docker image..."
	@docker build -t $(IMAGE_NAME) .

# --- Elastic Beanstalk Targets ---

eb-init:
	@echo "Initializing Elastic Beanstalk application..."
	@aws elasticbeanstalk create-application --application-name $(EB_APP_NAME) --region $(AWS_REGION) || true
	@if [ -z "$(S3_BUCKET)" ]; then \
		echo "Creating S3 bucket for Elastic Beanstalk..."; \
		ACCOUNT_ID=$$(aws sts get-caller-identity --query Account --output text); \
		BUCKET_NAME=elasticbeanstalk-$(AWS_REGION)-$$ACCOUNT_ID; \
		aws s3 mb s3://$$BUCKET_NAME --region $(AWS_REGION) || true; \
		echo "S3_BUCKET=$$BUCKET_NAME" >> .env_eb; \
	fi

eb-package:
	@echo "Creating source bundle (source.zip)..."
	@git archive -o source.zip HEAD .

deploy: eb-package eb-deploy

eb-deploy:
	@echo "Deploying to Elastic Beanstalk..."
	@TIMESTAMP=$$(date +%Y%m%d%H%M%S); \
	VERSION_LABEL="v$$TIMESTAMP"; \
	BUCKET=$$(if [ -n "$(S3_BUCKET)" ]; then echo "$(S3_BUCKET)"; else aws s3 ls | grep elasticbeanstalk-$(AWS_REGION) | awk '{print $$3}' | head -n 1; fi); \
	if [ -z "$$BUCKET" ]; then echo "Error: S3 bucket not found. Run 'make eb-init' first."; exit 1; fi; \
	aws s3 cp source.zip s3://$$BUCKET/$(EB_APP_NAME)/$$VERSION_LABEL.zip --region $(AWS_REGION); \
	aws elasticbeanstalk create-application-version --application-name $(EB_APP_NAME) \
		--version-label $$VERSION_LABEL --source-bundle S3Bucket=$$BUCKET,S3Key=$(EB_APP_NAME)/$$VERSION_LABEL.zip --region $(AWS_REGION); \
	aws elasticbeanstalk update-environment --environment-name $(EB_ENV_NAME) --version-label $$VERSION_LABEL --region $(AWS_REGION) || \
	aws elasticbeanstalk create-environment --application-name $(EB_APP_NAME) --environment-name $(EB_ENV_NAME) \
		--version-label $$VERSION_LABEL --solution-stack-name "$(EB_SOLUTION_STACK)" --region $(AWS_REGION)

eb-status:
	@echo "Checking Elastic Beanstalk status for $(EB_ENV_NAME)..."
	@aws elasticbeanstalk describe-environments --environment-names $(EB_ENV_NAME) --region $(AWS_REGION) \
		--query 'Environments[0].{Status:Status, Health:Health, URL:CNAME}' --output table

eb-endpoint:
	@echo "Elastic Beanstalk public endpoint:"
	@aws elasticbeanstalk describe-environments --environment-names $(EB_ENV_NAME) --region $(AWS_REGION) \
		--query 'Environments[0].CNAME' --output text

aws-destroy:
	@echo "Destroying AWS resources for $(EB_APP_NAME)..."
	@aws elasticbeanstalk terminate-environment --environment-name $(EB_ENV_NAME) --region $(AWS_REGION) || true
	@echo "Note: The application and S3 buckets are not automatically deleted by this target for safety."

help:
	@echo "Makefile for the Rust project (Elastic Beanstalk)"
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
	@echo "    eb-init          Initialize EB Application and S3 bucket"
	@echo "    deploy           Package and deploy to Elastic Beanstalk"
	@echo "    eb-status        Check EB environment status"
	@echo "    eb-endpoint      Get the public CNAME URL"
	@echo "    aws-destroy      Terminate EB environment"
