export AWS_PAGER :=
# Makefile for ADK Comic Pipeline (EKS Support)

# Include and export AWS credentials if they exist
-include .aws_creds
export

# AWS Configuration
AWS_REGION ?= us-east-1
AWS_ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null)
IMAGE_NAME ?= adk-comic-image
ECR_REPOSITORY ?= $(IMAGE_NAME)
ECR_URI ?= $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPOSITORY)

# EKS Configuration
EKS_CLUSTER ?= adkui-eks-cluster
EKS_NAMESPACE ?= default
EKS_REGION ?= $(AWS_REGION)

# Binary names
EKSCTL ?= eksctl
KUBECTL ?= kubectl

.PHONY: clean test deploy run endpoint status aws-destroy cluster-create cluster-delete eks-deploy eks docker-build ecr-login push-ecr logs eks-update-kubeconfig

clean:
	@echo "Cleaning up generated images and temporary files..."
	find . -name "*.log" -delete 2>/dev/null || true
	find images -name "*.png" -delete 2>/dev/null || true
	find output/images -name "*.png" -delete 2>/dev/null || true
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type d -name ".adk" -exec rm -rf {} +
	rm -f k8s-deployment.yaml
	@echo "Clean completed."

deploy: eks

status: endpoint

# EKS Specific targets
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

logs:
	@echo "Tailing logs for EKS pods with label app=$(IMAGE_NAME)..."
	@$(KUBECTL) logs -l app=$(IMAGE_NAME) -n $(EKS_NAMESPACE) --follow

endpoint:
	@echo "Fetching EKS LoadBalancer endpoint..."
	@$(KUBECTL) get service $(IMAGE_NAME)-service -n $(EKS_NAMESPACE) -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

aws-destroy:
	@echo "Destroying AWS resources for EKS..."
	@$(KUBECTL) delete -f k8s-deployment.yaml 2>/dev/null || true
	@aws ecr delete-repository --repository-name $(ECR_REPOSITORY) --region $(AWS_REGION) --force 2>/dev/null || true
	@echo "AWS resources destroyed."
