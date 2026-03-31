export AWS_PAGER :=
# Makefile for mcp-stdio-python

# Include and export AWS credentials if they exist
-include .aws_creds
export

# AWS Configuration
AWS_REGION ?= us-east-1
SERVICE_NAME ?= mcp-express-python-aws
IMAGE_NAME ?= mcp-server-image

# ECS Express Mode Configuration
ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query "Account" --output text)
ECR_REPO_NAME ?= mcp-server-repo
IMAGE_TAG ?= latest
ECR_IMAGE_URI ?= $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO_NAME):$(IMAGE_TAG)
ECS_SERVICE_NAME ?= $(SERVICE_NAME)

.PHONY: all install run build test lint format type-check status git-status ecs-status endpoint pull push clean deploy docker-build ecr-push ecs-deploy aws-destroy ecr-setup ecr-login iam-roles

# Target to show both git and ECS status
status: ecs-status

# Target to show git status
git-status:
	@echo "Showing git status..."
	@git status

# Target to show AWS ECS status
ecs-status:
	@echo "Checking AWS ECS service status for $(ECS_SERVICE_NAME)..."
	@aws ecs describe-express-gateway-service --service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/$(ECS_SERVICE_NAME) 2>/dev/null | \
		python3 -c "import sys, json; data = json.load(sys.stdin); s = data['service']; \
		status = s['status']['statusCode']; \
		endpoint = s['activeConfigurations'][0]['ingressPaths'][0]['endpoint'] if s.get('activeConfigurations') else 'N/A'; \
		print(f\"Service: {s['serviceName']}\nStatus: {status}\nEndpoint: {endpoint}\")" || \
		echo "Service $(ECS_SERVICE_NAME) not found or error parsing status."

# Target to get the public endpoint URL
endpoint:
	@aws ecs describe-express-gateway-service --service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/$(ECS_SERVICE_NAME) \
		--query 'service.endpoint' --output text

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

# IAM roles for ECS Express Mode
iam-roles:
	@echo "Creating IAM roles for ECS Express Mode..."
	@# Task Execution Role
	@aws iam get-role --role-name ecsTaskExecutionRole 2>/dev/null || \
		(aws iam create-role --role-name ecsTaskExecutionRole \
			--assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}' && \
		aws iam attach-role-policy --role-name ecsTaskExecutionRole \
			--policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy)
	@# Infrastructure Role
	@aws iam get-role --role-name ecsInfrastructureRoleForExpressServices 2>/dev/null || \
		(aws iam create-role --role-name ecsInfrastructureRoleForExpressServices \
			--assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs.amazonaws.com"},"Action":"sts:AssumeRole"}]}' && \
		aws iam attach-role-policy --role-name ecsInfrastructureRoleForExpressServices \
			--policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRoleforExpressGatewayServices)

# ECR setup and push
ecr-setup:
	@echo "Ensuring ECR repository exists..."
	@aws ecr describe-repositories --repository-names $(ECR_REPO_NAME) 2>/dev/null || \
		aws ecr create-repository --repository-name $(ECR_REPO_NAME)

ecr-login:
	@echo "Logging into ECR..."
	@aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

ecr-push: ecr-setup ecr-login docker-build
	@echo "Pushing image to ECR..."
	@docker tag $(IMAGE_NAME) $(ECR_IMAGE_URI)
	@docker push $(ECR_IMAGE_URI)

# ECS Express Mode Deployment
deploy: ecr-push iam-roles ecs-deploy

ecs-deploy:
	@echo "Deploying to ECS Express Mode..."
	@aws ecs describe-express-gateway-service --service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/$(ECS_SERVICE_NAME) 2>/dev/null && \
		(echo "Updating existing service..." && \
		aws ecs update-express-gateway-service \
			--service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/$(ECS_SERVICE_NAME) \
			--primary-container "image=$(ECR_IMAGE_URI),containerPort=8080") || \
		(echo "Creating new service..." && \
		aws ecs create-express-gateway-service \
			--service-name $(ECS_SERVICE_NAME) \
			--primary-container "image=$(ECR_IMAGE_URI),containerPort=8080" \
			--execution-role-arn arn:aws:iam::$(ACCOUNT_ID):role/ecsTaskExecutionRole \
			--infrastructure-role-arn arn:aws:iam::$(ACCOUNT_ID):role/ecsInfrastructureRoleForExpressServices \
			--monitor-resources)

aws-destroy:
	@echo "Destroying AWS resources for $(ECS_SERVICE_NAME)..."
	@aws ecs delete-express-gateway-service --service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/$(ECS_SERVICE_NAME) 2>/dev/null || true
	@echo "AWS resources destroyed."

.PHONY: clean
clean:
	@echo "Cleaning up..."
	@find . -type f -name "*.pyc" -delete
	@find . -type d -name "__pycache__" -exec rm -rf {} +
	@find . -type d -name ".pyte*" -exec rm -rf {} +
	@find . -type d -name ".mypy*" -exec rm -rf {} +
	@rm -rf .venv
