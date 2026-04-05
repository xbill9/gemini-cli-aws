export AWS_PAGER :=
# Makefile for ADK Comic Pipeline on AWS ECS Express Mode

# Include and export AWS credentials if they exist
-include .aws_creds
export

# AWS Configuration
AWS_REGION ?= us-east-1
SERVICE_NAME ?= adkui-ecsexpress
IMAGE_NAME ?= adkui-image

# ECS Express Mode Configuration
ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query "Account" --output text 2>/dev/null)
ECR_REPO_NAME ?= adkui-repo
IMAGE_TAG ?= latest
ECR_IMAGE_URI ?= $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO_NAME):$(IMAGE_TAG)
ECS_SERVICE_NAME ?= $(SERVICE_NAME)

# ADK Configuration for Vertex AI
PROJECT_ID := $(shell [ -f ~/project_id.txt ] && cat ~/project_id.txt || echo "N/A")
GEMINI_API_KEY := $(shell [ -f ~/gemini.key ] && cat ~/gemini.key || echo "N/A")
GOOGLE_CLOUD_LOCATION ?= us-central1

# Environment variables for the primary container
ENV_VARS := "image=$(ECR_IMAGE_URI),containerPort=8080,environment=[{name=GOOGLE_CLOUD_PROJECT,value=$(PROJECT_ID)},{name=GOOGLE_CLOUD_LOCATION,value=$(GOOGLE_CLOUD_LOCATION)},{name=GOOGLE_API_KEY,value=$(GEMINI_API_KEY)},{name=GEMINI_API_KEY,value=$(GEMINI_API_KEY)},{name=MODEL_ID,value=gemini-2.5-flash-native-audio-preview-12-2025}]"

.PHONY: clean test deploy run endpoint status ecs-status lightsail-status aws-destroy docker-build ecr-push ecr-setup ecr-login iam-roles ecs-deploy

clean:
	@echo "Cleaning up generated images and temporary files..."
	find . -name "*.log" -delete 2>/dev/null || true
	find images -name "*.png" -delete 2>/dev/null || true
	find output/images -name "*.png" -delete 2>/dev/null || true
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type d -name ".adk" -exec rm -rf {} +
	@echo "Clean completed."

# Primary deploy command
deploy: ecr-push iam-roles ecs-deploy

# Target to show AWS ECS status
status: ecs-status

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

# Build the Docker image
docker-build:
	@echo "Building the Docker image..."
	@docker build -t $(IMAGE_NAME) .

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
ecs-deploy:
	@echo "Deploying to ECS Express Mode..."
	@if aws ecs describe-express-gateway-service --service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/$(ECS_SERVICE_NAME) 2>/dev/null; then \
                echo "Updating existing service..." && \
                NET_CONFIG=$$(aws ecs describe-express-gateway-service --service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/$(ECS_SERVICE_NAME) --query 'service.activeConfigurations[0].networkConfiguration' --output json | jq -c .) && \
                aws ecs update-express-gateway-service \
                        --service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/$(ECS_SERVICE_NAME) \
                        --health-check-path /docs \
                        --network-configuration "$$NET_CONFIG" \
                        --primary-container $(ENV_VARS); \
        else \
                echo "Creating new service..." && \
                aws ecs create-express-gateway-service \
                        --service-name $(ECS_SERVICE_NAME) \
                        --health-check-path /docs \
                        --primary-container $(ENV_VARS) \
                        --execution-role-arn arn:aws:iam::$(ACCOUNT_ID):role/ecsTaskExecutionRole \
                        --infrastructure-role-arn arn:aws:iam::$(ACCOUNT_ID):role/ecsInfrastructureRoleForExpressServices \
                        --monitor-resources; \
        fi

aws-destroy:
	@echo "Destroying AWS resources for $(ECS_SERVICE_NAME)..."
	@aws ecs delete-express-gateway-service --service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/$(ECS_SERVICE_NAME) 2>/dev/null || true
	@echo "AWS resources destroyed."

# Legacy Lightsail targets
deploy-lightsail:
	./save-aws-creds.sh
	./deploy-lightsail.sh

lightsail-status:
	@aws lightsail get-container-services --service-name agent-service --region us-east-1 \
		--query 'containerServices[0].{State:state, Deployment:currentDeployment.state, URL:publicEndpoint.url}' \
		--output table
