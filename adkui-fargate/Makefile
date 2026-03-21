# Makefile for ADK Comic Pipeline

# Include and export AWS credentials if they exist
-include .aws_creds
export

# AWS Configuration
AWS_REGION ?= us-east-1
AWS_ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null)
IMAGE_NAME ?= adk-ui-image
ECR_REPOSITORY ?= $(IMAGE_NAME)
ECR_URI ?= $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPOSITORY)

# ECS Configuration
ECS_CLUSTER ?= adk-fargate-cluster
ECS_SERVICE ?= adk-fargate-service
TASK_FAMILY ?= adk-fargate-task
CONTAINER_NAME ?= adk-ui-container

# GCP Configuration (needed for GenAI)
# Try to load from various sources
GOOGLE_CLOUD_PROJECT ?= $(shell (cat ~/project_id.txt 2>/dev/null || grep GOOGLE_CLOUD_PROJECT .env 2>/dev/null | cut -d= -f2))
GOOGLE_API_KEY ?= $(shell (cat ${HOME}/gemini.key 2>/dev/null || grep GOOGLE_API_KEY .env 2>/dev/null | cut -d= -f2))

.PHONY: clean test deploy run fargate ecs-status endpoint logs delete-service delete-cluster ecr-login push-ecr register-task create-cluster update-or-create-service create-service status

clean:
	@echo "Cleaning up generated images and temporary files..."
	find . -name "*.log" -delete 2>/dev/null || true
	find images -name "*.png" -delete 2>/dev/null || true
	find output/images -name "*.png" -delete 2>/dev/null || true
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type d -name ".adk" -exec rm -rf {} +
	@echo "Clean completed."

run:
	@echo "Running ADK locally..."
	adk web . --host 0.0.0.0 --port 8080

# Deployment
deploy: fargate

fargate: create-log-group create-cluster docker-build ecr-login push-ecr register-task update-or-create-service

docker-build:
	@echo "Building the Docker image..."
	@docker build -t $(IMAGE_NAME) .

ecr-login:
	@echo "Logging in to Amazon ECR..."
	@aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

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
	     -e 's|{{GOOGLE_CLOUD_PROJECT}}|$(GOOGLE_CLOUD_PROJECT)|g' \
	     -e 's|{{GOOGLE_API_KEY}}|$(GOOGLE_API_KEY)|g' \
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

# Monitoring
status: ecs-status

ecs-status:
	@echo "Checking AWS ECS service status for $(ECS_SERVICE) in cluster $(ECS_CLUSTER)..."
	@aws ecs describe-services --cluster $(ECS_CLUSTER) --services $(ECS_SERVICE) --region $(AWS_REGION) \
		--query 'services[0].{Status:status, ServiceName:serviceName, TaskDefinition:taskDefinition, Desired:desiredCount, Running:runningCount}' \
		--output table

endpoint:
	@echo "Querying ECS tasks for $(ECS_SERVICE)..."
	@TASK_ARN=$$(aws ecs list-tasks --cluster $(ECS_CLUSTER) --service-name $(ECS_SERVICE) --query 'taskArns[0]' --output text --region $(AWS_REGION)) && \
	ENI_ID=$$(aws ecs describe-tasks --cluster $(ECS_CLUSTER) --tasks $$TASK_ARN --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text --region $(AWS_REGION)) && \
	aws ec2 describe-network-interfaces --network-interface-ids $$ENI_ID --query 'NetworkInterfaces[0].Association.PublicIp' --output text --region $(AWS_REGION)

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
