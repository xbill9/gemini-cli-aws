export AWS_PAGER :=
# Makefile for mcp-eks-python-aws

# Include and export AWS credentials if they exist
-include .aws_creds
export

# AWS Configuration
AWS_REGION ?= us-east-1
AWS_ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null)
IMAGE_NAME ?= mcp-server-image
ECR_REPOSITORY ?= $(IMAGE_NAME)
ECR_URI ?= $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPOSITORY)

# EKS Configuration
EKS_CLUSTER ?= mcp-eks-cluster
EKS_NAMESPACE ?= default
EKS_REGION ?= $(AWS_REGION)

# Binary names
EKSCTL ?= eksctl
KUBECTL ?= kubectl

# Default target
all: install lint format type-check test docker-build

help:
	@echo "Available Makefile commands:"
	@echo "  install           Install Python dependencies"
	@echo "  run               Run the server locally"
	@echo "  test              Run the pytest suite"
	@echo "  lint              Run flake8 linting"
	@echo "  format            Format code with black"
	@echo "  type-check        Run mypy type checking"
	@echo "  deploy (or eks)   Update kubeconfig, build image, and deploy to EKS"
	@echo "  status            Check EKS deployment status"
	@echo "  endpoint          Fetch the LoadBalancer hostname"
	@echo "  logs              Tail logs for the EKS pods"
	@echo "  cluster-create    Create EKS cluster using eks-cluster.yaml"
	@echo "  cluster-delete    Delete EKS cluster"
	@echo "  aws-destroy       Clean up EKS resources and ECR repository"
	@echo "  clean             Remove temporary files and virtual environments"

.PHONY: all help install run build test lint format type-check status git-status endpoint pull push clean deploy eks docker-build ecr-login push-ecr logs eks-update-kubeconfig eks-deploy aws-destroy cluster-create cluster-delete release

# Installation and Execution
install:
	@echo "Installing dependencies..."
	python3 -m pip install -r requirements.txt

run:
	@echo "Running the server locally..."
	python3 main.py

release: install run

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
	PYTHONPATH=. python -m pytest

# Monitoring
status:
	@echo "Checking AWS EKS deployment status..."
	@$(KUBECTL) get deployments -n $(EKS_NAMESPACE)
	@$(KUBECTL) get services -n $(EKS_NAMESPACE)

# Target to show git status
git-status:
	@echo "Showing git status..."
	@git status

# Target to get the public endpoint
endpoint:
	@echo "Fetching EKS LoadBalancer endpoint..."
	@$(KUBECTL) get service $(IMAGE_NAME)-service -n $(EKS_NAMESPACE) -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

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

# Deploy to Amazon EKS
deploy: eks-deploy
eks: eks-deploy

cluster-create:
	@echo "Creating EKS cluster $(EKS_CLUSTER) in $(EKS_REGION) using eks-cluster.yaml..."
	@$(EKSCTL) create cluster -f eks-cluster.yaml

cluster-delete:
	@echo "Deleting EKS cluster $(EKS_CLUSTER) in $(EKS_REGION)..."
	@$(EKSCTL) delete cluster -f eks-cluster.yaml

eks-update-kubeconfig:
	@echo "Updating kubeconfig for cluster $(EKS_CLUSTER)..."
	@aws eks update-kubeconfig --name $(EKS_CLUSTER) --region $(AWS_REGION)

eks-deploy: eks-update-kubeconfig docker-build ecr-login push-ecr
	@echo "Deploying to Amazon EKS..."
	@sed -e 's|{{ECR_URI}}|$(ECR_URI)|g' \
	     -e 's|{{IMAGE_NAME}}|$(IMAGE_NAME)|g' \
	     k8s-deployment.yaml.template > k8s-deployment.yaml
	@$(KUBECTL) apply -f k8s-deployment.yaml

push-ecr:
	@echo "Tagging and pushing the Docker image to ECR..."
	@docker tag $(IMAGE_NAME):latest $(ECR_URI):latest
	@aws ecr describe-repositories --repository-names $(ECR_REPOSITORY) --region $(AWS_REGION) || \
		aws ecr create-repository --repository-name $(ECR_REPOSITORY) --region $(AWS_REGION)
	@docker push $(ECR_URI):latest

logs:
	@echo "Tailing logs for EKS pods with label app=$(IMAGE_NAME)..."
	@$(KUBECTL) logs -l app=$(IMAGE_NAME) -n $(EKS_NAMESPACE) --follow

aws-destroy:
	@echo "Deleting EKS resources..."
	@$(KUBECTL) delete -f k8s-deployment.yaml 2>/dev/null || true
	@rm -f k8s-deployment.yaml
	@echo "Deleting ECR repository $(ECR_REPOSITORY)..."
	@aws ecr delete-repository --repository-name $(ECR_REPOSITORY) --region $(AWS_REGION) --force 2>/dev/null || true
	@echo "AWS resources destroyed."

.PHONY: clean
clean:
	@echo "Cleaning up..."
	@find . -type f -name "*.pyc" -delete
	@find . -type d -name "__pycache__" -exec rm -rf {} +
	@find . -type d -name ".pyte*" -exec rm -rf {} +
	@find . -type d -name ".mypy*" -exec rm -rf {} +
	@rm -rf .venv
	@rm -f k8s-deployment.yaml
