export AWS_PAGER :=
# Makefile for ADK Mission Alpha: Biometric Scout (EKS Deployment)

# Include and export AWS credentials if they exist
-include .aws_creds
export

.PHONY: clean test deploy run endpoint status eks-deploy eks-status eks-destroy ecr-setup ecr-login ecr-push credentials frontend mock

# AWS Configuration
AWS_REGION ?= us-east-1
SERVICE_NAME ?= biometric-scout-service
IMAGE_NAME ?= biometric-scout-image
CLUSTER_NAME ?= biometric-scout-cluster

# EKS Configuration
ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query "Account" --output text 2>/dev/null)
ECR_REPO_NAME ?= biometric-scout-repo
IMAGE_TAG ?= latest
ECR_IMAGE_URI ?= $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO_NAME):$(IMAGE_TAG)

clean:
	@echo "Cleaning up generated images and temporary files..."
	find . -name "*.log" -delete 2>/dev/null || true
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type d -name ".adk" -exec rm -rf {} +
	rm -f k8s-deployment.yaml primary.json
	@echo "Clean completed."

frontend:
	cd frontend && npm install && npm run build

mock:
	python mock/mock_server.py

# ECR setup and push
ecr-setup:
	@echo "Ensuring ECR repository exists..."
	@aws ecr describe-repositories --repository-names $(ECR_REPO_NAME) 2>/dev/null || \
		aws ecr create-repository --repository-name $(ECR_REPO_NAME)

ecr-login:
	@echo "Logging into ECR..."
	@aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

ecr-push: ecr-setup ecr-login
	@echo "Building and pushing image to ECR..."
	docker build -t $(IMAGE_NAME) .
	docker tag $(IMAGE_NAME) $(ECR_IMAGE_URI)
	docker push $(ECR_IMAGE_URI)

credentials:
	./save-aws-creds.sh

# Load environment variables for deployment
-include .env
export

deploy: credentials ecr-push eks-deploy

eks-deploy:
	./deploy-eks.sh

eks-status:
	@echo "Checking EKS cluster and pods status..."
	@kubectl get pods -l app=$(IMAGE_NAME) 2>/dev/null || echo "No pods found."
	@echo "Checking Service status..."
	@kubectl get svc $(IMAGE_NAME)-service 2>/dev/null || echo "Service not found."

eks-destroy:
	@echo "Deleting EKS deployment and service..."
	kubectl delete -f k8s-deployment.yaml 2>/dev/null || true
	@echo "Note: This does NOT delete the EKS cluster. To delete the cluster, run: eksctl delete cluster --name $(CLUSTER_NAME) --region $(AWS_REGION)"

status: eks-status

endpoint:
	@kubectl get svc $(IMAGE_NAME)-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
	@echo ""
