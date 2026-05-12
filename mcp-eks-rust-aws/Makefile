# Makefile for the Rust project (Amazon EKS)

# Include and export AWS credentials if they exist
-include .aws_creds
export

export AWS_PAGER :=

# Variables
SERVICE_NAME := mcp-eks-rust-aws
IMAGE_NAME := mcp-server-image

# AWS Configuration
AWS_REGION ?= us-east-1
AWS_ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null)
ECR_REPOSITORY ?= $(SERVICE_NAME)
ECR_URI ?= $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPOSITORY)

# EKS Configuration
EKS_CLUSTER ?= mcp-eks-cluster
EKS_NAMESPACE ?= default
EKS_REGION ?= $(AWS_REGION)

# Binary names
EKSCTL ?= eksctl
KUBECTL ?= kubectl

.PHONY: all build run clean release test fmt clippy lint check docker-build deploy eks status git-status endpoint ecr-login push-ecr cluster-create cluster-delete eks-update-kubeconfig eks-deploy aws-destroy logs start stop help

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
	@rm -f server.pid server.log k8s-deployment.yaml eks-cluster.yaml

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

# --- AWS EKS Deployment ---

deploy: eks-deploy
eks: eks-deploy

cluster-create:
	@echo "Creating EKS cluster $(EKS_CLUSTER) in $(EKS_REGION) using eks-cluster.yaml..."
	@sed -e 's|{{EKS_CLUSTER}}|$(EKS_CLUSTER)|g' \
	     -e 's|{{AWS_REGION}}|$(AWS_REGION)|g' \
	     eks-cluster.yaml.template > eks-cluster.yaml
	@$(EKSCTL) create cluster -f eks-cluster.yaml

cluster-delete:
	@echo "Deleting EKS cluster $(EKS_CLUSTER) in $(EKS_REGION)..."
	@$(EKSCTL) delete cluster --name $(EKS_CLUSTER) --region $(AWS_REGION)

eks-update-kubeconfig:
	@echo "Updating kubeconfig for cluster $(EKS_CLUSTER)..."
	@aws eks update-kubeconfig --name $(EKS_CLUSTER) --region $(AWS_REGION)

eks-deploy: eks-update-kubeconfig push-ecr
	@echo "Deploying to Amazon EKS..."
	@sed -e 's|{{ECR_URI}}|$(ECR_URI)|g' \
	     -e 's|{{IMAGE_NAME}}|$(IMAGE_NAME)|g' \
	     k8s-deployment.yaml.template > k8s-deployment.yaml
	@$(KUBECTL) apply -f k8s-deployment.yaml

# Monitor EKS logs
logs:
	@echo "Tailing logs for EKS pods with label app=$(IMAGE_NAME)..."
	@$(KUBECTL) logs -l app=$(IMAGE_NAME) -n $(EKS_NAMESPACE) --follow

# Status of EKS deployment
eks-status:
	@echo "Checking AWS EKS deployment status..."
	@$(KUBECTL) get deployments -n $(EKS_NAMESPACE)
	@$(KUBECTL) get services -n $(EKS_NAMESPACE)

# Target to get the public endpoint
endpoint:
	@echo "Fetching EKS LoadBalancer endpoint..."
	@$(KUBECTL) get service $(IMAGE_NAME)-service -n $(EKS_NAMESPACE) -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

git-status:
	@git status

aws-destroy:
	@echo "Deleting EKS resources..."
	@$(KUBECTL) delete -f k8s-deployment.yaml 2>/dev/null || true
	@rm -f k8s-deployment.yaml
	@echo "Deleting ECR repository $(ECR_REPOSITORY)..."
	@aws ecr delete-repository --repository-name $(ECR_REPOSITORY) --region $(AWS_REGION) --force 2>/dev/null || true
	@echo "AWS resources destroyed."

help:
	@echo "Makefile for the Rust project (Amazon EKS)"
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
	@echo "    deploy (or eks)  Update kubeconfig, build image, and deploy to EKS"
	@echo "    eks-status       Check EKS deployment status"
	@echo "    endpoint         Fetch the LoadBalancer hostname"
	@echo "    logs             Tail EKS logs"
	@echo "    cluster-create   Create EKS cluster using eks-cluster.yaml"
	@echo "    cluster-delete   Delete EKS cluster"
	@echo "    aws-destroy      Destroy AWS resources"
