# Makefile for mcp-fargate-python-aws

# Include and export AWS credentials if they exist
-include .aws_creds
export

# AWS Fargate Configuration
AWS_REGION ?= us-east-1
AWS_ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null)
IMAGE_NAME ?= mcp-server-image
ECR_REPOSITORY ?= $(IMAGE_NAME)
ECR_URI ?= $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPOSITORY)

# ECS Configuration
ECS_CLUSTER ?= mcp-fargate-cluster
ECS_SERVICE ?= mcp-fargate-service
TASK_FAMILY ?= mcp-fargate-task
CONTAINER_NAME ?= mcp-server-container

# Default target
all: install lint format type-check test docker-build

.PHONY: all install run build test lint format type-check status git-status ecs-status endpoint pull push clean deploy docker-build ecr-login push-ecr register-task update-or-create-service create-cluster create-service create-log-group logs delete-service delete-cluster

# Installation and Execution
install:
	@echo "Installing dependencies..."
	pip install -r requirements.txt

run:
	@echo "Running the server locally..."
	python main.py

# Code Quality and Testing
lint:
	@echo "Running linting (flake8)..."
	flake8 .

format:
	@echo "Formatting code (black)..."
	black .

type-check:
	@echo "Running type checking (mypy)..."
	mypy .

test:
	@echo "Running tests (pytest)..."
	pytest

# Monitoring
status: ecs-status

# Target to show git status
git-status:
	@echo "Showing git status..."
	@git status

# Target to show AWS ECS status
ecs-status:
	@echo "Checking AWS ECS service status for $(ECS_SERVICE) in cluster $(ECS_CLUSTER)..."
	@aws ecs describe-services --cluster $(ECS_CLUSTER) --services $(ECS_SERVICE) --region $(AWS_REGION) \
		--query 'services[0].{Status:status, ServiceName:serviceName, TaskDefinition:taskDefinition, Desired:desiredCount, Running:runningCount}' \
		--output table

# Target to get the public IP (Note: Fargate tasks with public IPs require querying the task's ENI)
endpoint:
	@echo "Querying ECS tasks for $(ECS_SERVICE)..."
	@TASK_ARN=$$(aws ecs list-tasks --cluster $(ECS_CLUSTER) --service-name $(ECS_SERVICE) --query 'taskArns[0]' --output text --region $(AWS_REGION)) && \
	ENI_ID=$$(aws ecs describe-tasks --cluster $(ECS_CLUSTER) --tasks $$TASK_ARN --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text --region $(AWS_REGION)) && \
	aws ec2 describe-network-interfaces --network-interface-ids $$ENI_ID --query 'NetworkInterfaces[0].Association.PublicIp' --output text --region $(AWS_REGION)

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

# Login to ECR
ecr-login:
	@echo "Logging in to Amazon ECR..."
	@aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

# Deploy to Amazon Fargate
deploy: fargate
fargate: create-log-group create-cluster docker-build ecr-login push-ecr register-task update-or-create-service

push-ecr:
	@echo "Tagging and pushing the Docker image to ECR..."
	@docker tag $(IMAGE_NAME):latest $(ECR_URI):latest
	@aws ecr describe-repositories --repository-names $(ECR_REPOSITORY) --region $(AWS_REGION) || \
		aws ecr create-repository --repository-name $(ECR_REPOSITORY) --region $(AWS_REGION)
	@docker push $(ECR_URI):latest

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

logs:
	@echo "Tailing logs for /ecs/$(TASK_FAMILY)..."
	@aws logs tail /ecs/$(TASK_FAMILY) --follow --region $(AWS_REGION)

delete-service:
	@echo "Deleting service $(ECS_SERVICE)..."
	@aws ecs update-service --cluster $(ECS_CLUSTER) --service $(ECS_SERVICE) --desired-count 0 --region $(AWS_REGION)
	@aws ecs delete-service --cluster $(ECS_CLUSTER) --service $(ECS_SERVICE) --region $(AWS_REGION)

delete-cluster:
	@echo "Deleting cluster $(ECS_CLUSTER)..."
	@aws ecs delete-cluster --cluster $(ECS_CLUSTER) --region $(AWS_REGION)

.PHONY: clean
clean:
	@echo "Cleaning up..."
	@find . -type f -name "*.pyc" -delete
	@find . -type d -name "__pycache__" -exec rm -rf {} +
	@find . -type d -name ".pyte*" -exec rm -rf {} +
	@find . -type d -name ".mypy*" -exec rm -rf {} +
	@rm -rf .venv
	@rm -f task-definition.json
