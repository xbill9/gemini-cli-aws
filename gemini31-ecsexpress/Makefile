SHELL = /bin/bash

export AWS_PAGER :=

# Makefile for Biometric Security System

# Include and export AWS credentials if they exist
-include .aws_creds
export

.PHONY: clean test lint deploy run endpoint frontend mock adk testadk status aws-destroy ecr-setup ecr-login ecr-push ecs-deploy iam-roles credentials

# AWS Configuration
AWS_REGION ?= us-east-1
SERVICE_NAME ?= biometric-scout
IMAGE_NAME ?= biometric-scout-image

# ECS Express Mode Configuration
ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query "Account" --output text 2>/dev/null)
ECR_REPO_NAME ?= biometric-scout-repo
IMAGE_TAG ?= latest
ECR_IMAGE_URI ?= $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO_NAME):$(IMAGE_TAG)
ECS_SERVICE_NAME ?= $(SERVICE_NAME)

clean:
	@echo "Cleaning up logs, caches, and temporary files..."
	find . -type f -name "*.log" -delete 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".adk" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".ruff_cache" -exec rm -rf {} + 2>/dev/null || true
	rm -rf frontend/dist 2>/dev/null || true
	@echo "Clean completed."

test:
	python -m pytest

lint:
	ruff check .
	ruff format --check .
	cd frontend && npm run lint

frontend:
	cd frontend && npm install && npm run build

run:
	. ./biosync.sh

mock:
	. ./mock.sh

adk:
	. ./runadk.sh

testadk:
	. ./testadk.sh

# IAM roles for ECS Express Mode
iam-roles: credentials
	@echo "Creating IAM roles for ECS Express Mode..."
	@aws iam get-role --role-name ecsTaskExecutionRole 2>/dev/null || (aws iam create-role --role-name ecsTaskExecutionRole --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}' && aws iam attach-role-policy --role-name ecsTaskExecutionRole --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy)
	@aws iam get-role --role-name ecsInfrastructureRoleForExpressServices 2>/dev/null || (aws iam create-role --role-name ecsInfrastructureRoleForExpressServices --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs.amazonaws.com"},"Action":"sts:AssumeRole"}]}' && aws iam attach-role-policy --role-name ecsInfrastructureRoleForExpressServices --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRoleforExpressGatewayServices)

# ECR setup and push
ecr-setup:
	@echo "Ensuring ECR repository exists..."
	@aws ecr describe-repositories --repository-names $(ECR_REPO_NAME) 2>/dev/null || aws ecr create-repository --repository-name $(ECR_REPO_NAME)

ecr-login:
	@echo "Logging into ECR..."
	@aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

ecr-push: ecr-setup ecr-login
	@echo "Building and pushing image to ECR..."
	docker build -t $(IMAGE_NAME) .
	docker tag $(IMAGE_NAME) $(ECR_IMAGE_URI)
	docker push $(ECR_IMAGE_URI)

# ECS Express Mode Deployment
credentials:
	./save-aws-creds.sh

deploy: credentials iam-roles ecr-push ecs-deploy

# Load environment variables for deployment
-include .env
export

ecs-deploy: credentials
	@echo "Deploying to ECS Express Mode..."
	@jq -n \
		--arg image "$(ECR_IMAGE_URI)" \
		--arg project "$(subst ",,$(GOOGLE_CLOUD_PROJECT))" \
		--arg location "$(subst ",,$(GOOGLE_CLOUD_LOCATION))" \
		--arg use_vertex "$(subst ",,$(GOOGLE_GENAI_USE_VERTEXAI))" \
		--arg api_key "$(subst ",,$(GOOGLE_API_KEY))" \
		--arg model_id "$(subst ",,$(MODEL_ID))" \
		'{image: $$image, containerPort: 8080, environment: [{name: "GOOGLE_CLOUD_PROJECT", value: $$project}, {name: "GOOGLE_CLOUD_LOCATION", value: $$location}, {name: "GOOGLE_GENAI_USE_VERTEXAI", value: $$use_vertex}, {name: "GOOGLE_API_KEY", value: $$api_key}, {name: "MODEL_ID", value: $$model_id}, {name: "PORT", value: "8080"}]}' > primary.json
	@PRIMARY_JSON=$$(jq -c . primary.json); \
	aws ecs describe-express-gateway-service --service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/$(ECS_SERVICE_NAME) 2>/dev/null && \
		(echo "Updating existing service..." && \
		aws ecs update-express-gateway-service \
			--service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/$(ECS_SERVICE_NAME) \
			--primary-container "$$PRIMARY_JSON") || \
		(echo "Creating new service..." && \
		aws ecs create-express-gateway-service \
			--service-name $(ECS_SERVICE_NAME) \
			--primary-container "$$PRIMARY_JSON" \
			--execution-role-arn arn:aws:iam::$(ACCOUNT_ID):role/ecsTaskExecutionRole \
			--infrastructure-role-arn arn:aws:iam::$(ACCOUNT_ID):role/ecsInfrastructureRoleForExpressServices \
			--monitor-resources)
	@rm primary.json

ecs-status:
	@echo "Checking AWS ECS service status for $(ECS_SERVICE_NAME)..."
	@aws ecs describe-express-gateway-service --service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/$(ECS_SERVICE_NAME) 2>/dev/null | \
		python3 -c "import sys, json; data = json.load(sys.stdin); s = data['service']; \
		status = s['status']['statusCode']; \
		endpoint = s['activeConfigurations'][0]['ingressPaths'][0]['endpoint'] if s.get('activeConfigurations') else 'N/A'; \
		print(f\"Service: {s['serviceName']}\nStatus: {status}\nEndpoint: {endpoint}\")" || \
		echo "Service $(ECS_SERVICE_NAME) not found or error parsing status."

status: ecs-status

endpoint:
	@aws ecs describe-express-gateway-service --service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/$(ECS_SERVICE_NAME) \
                --query 'service.activeConfigurations[0].ingressPaths[0].endpoint' --output text

aws-destroy:
	@echo "Destroying AWS resources for $(ECS_SERVICE_NAME)..."
	@aws ecs delete-express-gateway-service --service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/$(ECS_SERVICE_NAME) 2>/dev/null || true
	@echo "AWS resources destroyed."
