# Makefile for the Rust project (AWS Fargate)

# Include and export AWS credentials if they exist
-include .aws_creds
export

export AWS_PAGER :=

# Variables
SERVICE_NAME := mcp-fargate-rust-aws
IMAGE_NAME := mcp-server-image

# AWS Fargate Configuration
AWS_REGION ?= us-east-1
AWS_ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null)
ECR_REPOSITORY ?= $(SERVICE_NAME)
ECR_URI ?= $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPOSITORY)

# ECS Configuration
ECS_CLUSTER ?= mcp-fargate-cluster
ECS_SERVICE ?= mcp-fargate-service
TASK_FAMILY ?= mcp-fargate-task
CONTAINER_NAME ?= mcp-server-container

.PHONY: all build run clean release test fmt clippy lint check docker-build deploy fargate ecs-status monitor endpoint ecr-login push-ecr register-task update-or-create-service create-cluster create-service create-log-group logs delete-service delete-cluster aws-destroy iam-ecs-setup start stop status help

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
status: local-status

local-status:
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
	@rm -f server.pid server.log task-definition.json

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

# Alias for clippy
lint: clippy

# Check the code
check:
	@echo "Checking the code..."
	@cargo check

# Build the Docker image
docker-build:
	@echo "Building the Docker image..."
	@docker build -t $(IMAGE_NAME) .

# --- AWS ECR Targets ---

ecr-login:
	@echo "Logging in to Amazon ECR..."
	@aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

push-ecr: ecr-login docker-build
	@echo "Tagging and pushing the Docker image to ECR..."
	@docker tag $(IMAGE_NAME):latest $(ECR_URI):latest
	@aws ecr describe-repositories --repository-names $(ECR_REPOSITORY) --region $(AWS_REGION) || \
		aws ecr create-repository --repository-name $(ECR_REPOSITORY) --region $(AWS_REGION)
	@docker push $(ECR_URI):latest

# --- IAM Role Setup ---

iam-ecs-setup:
	@echo "Ensuring IAM roles for ECS exist..."
	@aws iam get-role --role-name ecsTaskExecutionRole > /dev/null 2>&1 || \
		(echo "Creating role ecsTaskExecutionRole..." && \
		aws iam create-role --role-name ecsTaskExecutionRole \
			--assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}' && \
		aws iam attach-role-policy --role-name ecsTaskExecutionRole \
			--policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy)

# --- AWS Fargate Deployment ---

deploy: fargate

fargate: iam-ecs-setup create-log-group create-cluster push-ecr register-task update-or-create-service

register-task:
	@echo "Registering a new task definition..."
	@sed -e 's|{{ECR_URI}}|$(ECR_URI)|g' \
	     -e 's|{{CONTAINER_NAME}}|$(CONTAINER_NAME)|g' \
	     -e 's|{{TASK_FAMILY}}|$(TASK_FAMILY)|g' \
	     -e 's|{{AWS_ACCOUNT_ID}}|$(AWS_ACCOUNT_ID)|g' \
	     -e 's|{{AWS_REGION}}|$(AWS_REGION)|g' \
	     task-definition.json.template > task-definition.json
	@aws ecs register-task-definition --cli-input-json file://task-definition.json --region $(AWS_REGION)

create-log-group:
	@echo "Ensuring CloudWatch log group /ecs/$(TASK_FAMILY) exists..."
	@aws logs create-log-group --log-group-name /ecs/$(TASK_FAMILY) --region $(AWS_REGION) 2>/dev/null || true

create-cluster:
	@echo "Ensuring ECS cluster $(ECS_CLUSTER) exists..."
	@aws ecs describe-clusters --clusters $(ECS_CLUSTER) --region $(AWS_REGION) --query 'clusters[0].status' --output text 2>/dev/null | grep -q "ACTIVE" || \
		aws ecs create-cluster --cluster $(ECS_CLUSTER) --region $(AWS_REGION)

update-or-create-service:
	@echo "Updating or creating the ECS service..."
	@aws ecs describe-services --cluster $(ECS_CLUSTER) --services $(ECS_SERVICE) --region $(AWS_REGION) --query 'services[0].status' --output text 2>/dev/null | grep -q "ACTIVE" && \
		(echo "Updating service $(ECS_SERVICE)..." && aws ecs update-service --cluster $(ECS_CLUSTER) --service $(ECS_SERVICE) --task-definition $(TASK_FAMILY) --region $(AWS_REGION)) || \
		(echo "Creating service $(ECS_SERVICE)..." && $(MAKE) create-service)

create-service:
	@echo "Creating a new Fargate service $(ECS_SERVICE)..."
	$(eval VPC_ID := $(shell aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text --region $(AWS_REGION)))
	$(eval SUBNETS := $(shell aws ec2 describe-subnets --filters "Name=vpc-id,Values=$(VPC_ID)" --query "Subnets[*].SubnetId" --output text --region $(AWS_REGION) | sed 's/\t/,/g'))
	$(eval SG_ID := $(shell aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$(VPC_ID)" "Name=group-name,Values=default" --query "SecurityGroups[0].GroupId" --output text --region $(AWS_REGION)))
	@aws ecs create-service \
		--cluster $(ECS_CLUSTER) \
		--service-name $(ECS_SERVICE) \
		--task-definition $(TASK_FAMILY) \
		--desired-count 1 \
		--launch-type FARGATE \
		--network-configuration "awsvpcConfiguration={subnets=[$(SUBNETS)],securityGroups=[$(SG_ID)],assignPublicIp=ENABLED}" \
		--region $(AWS_REGION)

# Monitor Fargate logs
logs:
	@echo "Tailing logs for /ecs/$(TASK_FAMILY)..."
	@aws logs tail /ecs/$(TASK_FAMILY) --follow --region $(AWS_REGION)

# Status of ECS deployment
ecs-status:
	@echo "Checking AWS ECS service status for $(ECS_SERVICE) in cluster $(ECS_CLUSTER)..."
	@aws ecs describe-services --cluster $(ECS_CLUSTER) --services $(ECS_SERVICE) --region $(AWS_REGION) \
		--query 'services[0].{Status:status, ServiceName:serviceName, TaskDefinition:taskDefinition, Desired:desiredCount, Running:runningCount}' \
		--output table

# Target to get the public IP
endpoint:
	@echo "Querying ECS tasks for $(ECS_SERVICE)..."
	@TASK_ARN=$$(aws ecs list-tasks --cluster $(ECS_CLUSTER) --service-name $(ECS_SERVICE) --query 'taskArns[0]' --output text --region $(AWS_REGION)) && \
	if [ -n "$$TASK_ARN" ] && [ "$$TASK_ARN" != "None" ]; then \
		ENI_ID=$$(aws ecs describe-tasks --cluster $(ECS_CLUSTER) --tasks $$TASK_ARN --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text --region $(AWS_REGION)) && \
		aws ec2 describe-network-interfaces --network-interface-ids $$ENI_ID --query 'NetworkInterfaces[0].Association.PublicIp' --output text --region $(AWS_REGION); \
	else \
		echo "No running tasks found for service $(ECS_SERVICE)."; \
	fi

monitor: ecs-status

aws-destroy: delete-service delete-cluster
	@echo "Deleting ECR repository $(ECR_REPOSITORY)..."
	@aws ecr delete-repository --repository-name $(ECR_REPOSITORY) --region $(AWS_REGION) --force 2>/dev/null || true
	@echo "Deleting Log Group /ecs/$(TASK_FAMILY)..."
	@aws logs delete-log-group --log-group-name /ecs/$(TASK_FAMILY) --region $(AWS_REGION) 2>/dev/null || true
	@echo "AWS resources destroyed."

delete-service:
	@echo "Deleting service $(ECS_SERVICE)..."
	@aws ecs update-service --cluster $(ECS_CLUSTER) --service $(ECS_SERVICE) --desired-count 0 --region $(AWS_REGION) 2>/dev/null || true
	@aws ecs delete-service --cluster $(ECS_CLUSTER) --service $(ECS_SERVICE) --region $(AWS_REGION) --force 2>/dev/null || true

delete-cluster:
	@echo "Deleting cluster $(ECS_CLUSTER)..."
	@aws ecs delete-cluster --cluster $(ECS_CLUSTER) --region $(AWS_REGION) 2>/dev/null || true

help:
	@echo "Makefile for the Rust project (AWS Fargate)"
	@echo ""
	@echo "Usage:"
	@echo "    make <target>"
	@echo ""
	@echo "Targets:"
	@echo "    all              (default) same as 'build'"
	@echo "    build            Build the project for development"
	@echo "    run              Run the project locally"
	@echo "    start            Start the server in the background"
	@echo "    stop             Stop the background server"
	@echo "    status           Get the status of the local background server"
	@echo "    clean            Clean the project"
	@echo "    release          Build the project for release"
	@echo "    test             Run tests"
	@echo "    fmt              Check formatting"
	@echo "    clippy           Lint the code"
	@echo "    lint             Alias for clippy"
	@echo "    check            Check the code"
	@echo "    docker-build     Build the Docker image"
	@echo "    deploy           Deploy to Amazon Fargate"
	@echo "    ecs-status       Check Fargate service status"
	@echo "    endpoint         Get the public IP of the running task"
	@echo "    logs             Tail CloudWatch logs"
	@echo "    aws-destroy      Destroy AWS resources"
