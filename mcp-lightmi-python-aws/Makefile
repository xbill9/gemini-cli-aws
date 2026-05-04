export AWS_PAGER :=
# Makefile for mcp-stdio-python

# Include and export AWS credentials if they exist
-include .aws_creds
export

# AWS Lightsail Configuration
AWS_REGION ?= us-east-1
SERVICE_NAME ?= mcp-lightsail-python-aws
IMAGE_NAME ?= mcp-server-image

# Lightsail Instance Configuration
INSTANCE_NAME ?= mcp-vps-python-aws
BLUEPRINT_ID ?= debian_13
BUNDLE_ID ?= nano_3_0
KEY_PAIR_NAME ?= mcp-vps-key
SSH_USER ?= admin

.PHONY: all install run build test lint format type-check status git-status lightsail-status instance-status endpoint pull push clean deploy docker-build push-lightsail create-deployment aws-destroy instance-deploy instance-create instance-setup-fw instance-sync instance-destroy

# Target to show both git, Container and Instance status
status: lightsail-status instance-status

# Target to show git status
git-status:
	@echo "Showing git status..."
	@git status

# Target to show AWS Lightsail container status
lightsail-status:
	@echo "Checking AWS Lightsail container service status for $(SERVICE_NAME)..."
	@aws lightsail get-container-services --service-name $(SERVICE_NAME) --region $(AWS_REGION) \
		--query 'containerServices[0].{State:state, Power:power, Deployment:currentDeployment.state, URL:publicEndpoint.url}' \
		--output table 2>/dev/null || echo "No container service found."

# Target to show AWS Lightsail instance status
instance-status:
	@echo "Checking AWS Lightsail instance status for $(INSTANCE_NAME)..."
	@aws lightsail get-instance --instance-name $(INSTANCE_NAME) --region $(AWS_REGION) \
		--query 'instance.{Name:name, State:state.name, PublicIp:publicIpAddress}' \
		--output table 2>/dev/null || echo "No instance found."

# Installation
install:
	@echo "Installing dependencies..."
	@pip install -r requirements.txt

# Run the server locally
run:
	@echo "Running the MCP server locally..."
	@python3 main.py

# Target to get the public endpoint URL (Lightsail Instance)
endpoint:
	@aws lightsail get-instance --instance-name $(INSTANCE_NAME) --region $(AWS_REGION) \
		--query 'instance.publicIpAddress' --output text | awk '{print "http://" $$1 ":8080"}'

# Code Quality
lint:
	@echo "Running flake8..."
	@flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics
	@flake8 . --count --exit-zero --max-complexity=10 --max-line-length=127 --statistics

format:
	@echo "Running black..."
	@black .

type-check:
	@echo "Running mypy..."
	@mypy .

test:
	@echo "Running pytest..."
	@PYTHONPATH=. python3 -m pytest

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


# Deploy to Amazon Lightsail (Default to Instance)
deploy: instance-deploy

# Container-based deployment
lightsail: docker-build push-lightsail create-deployment

push-lightsail:
	@echo "Pushing the Docker image to Lightsail..."
	@aws lightsail push-container-image --region $(AWS_REGION) --service-name $(SERVICE_NAME) --label $(IMAGE_NAME) --image $(IMAGE_NAME)

create-deployment:
	@echo "Creating a new deployment for Lightsail Container Service..."
	@IMAGE_IDENTIFIER=$$(aws lightsail get-container-images --service-name $(SERVICE_NAME) --query "containerImages[0].image" --output text) && \
	aws lightsail create-container-service-deployment --region $(AWS_REGION) \
		--service-name $(SERVICE_NAME) \
		--containers "{\"$(SERVICE_NAME)\":{\"image\":\"$$IMAGE_IDENTIFIER\",\"ports\":{\"8080\":\"HTTP\"}}}" \
		--public-endpoint "{\"containerName\":\"$(SERVICE_NAME)\",\"containerPort\":8080,\"healthCheck\":{\"path\":\"/health\"}}"

# Instance-based deployment
instance-deploy: instance-create
	@echo "Waiting for instance $(INSTANCE_NAME) to reach 'running' state..."
	@for i in {1..30}; do \
		STATE=$$(aws lightsail get-instance --instance-name $(INSTANCE_NAME) --query 'instance.state.name' --output text 2>/dev/null); \
		if [ "$$STATE" = "running" ]; then \
			echo "Instance is running."; \
			break; \
		fi; \
		echo "Current state: $$STATE. Waiting..."; \
		sleep 10; \
	done
	@$(MAKE) instance-setup-fw
	@echo "Waiting for SSH to be ready..."
	@sleep 20
	@$(MAKE) instance-sync

instance-create:
	@echo "Creating Lightsail instance $(INSTANCE_NAME)..."
	@aws lightsail create-instances \
		--instance-names $(INSTANCE_NAME) \
		--availability-zone $(AWS_REGION)a \
		--blueprint-id $(BLUEPRINT_ID) \
		--bundle-id $(BUNDLE_ID) \
		--key-pair-name $(KEY_PAIR_NAME) \
		--user-data file://scripts/setup-instance.sh 2>/dev/null || echo "Instance already exists or creation in progress."

instance-setup-fw:
	@echo "Opening port 8080 on $(INSTANCE_NAME)..."
	@aws lightsail open-instance-public-ports \
		--instance-name $(INSTANCE_NAME) \
		--port-info fromPort=8080,toPort=8080,protocol=tcp

instance-sync:
	@$(eval INSTANCE_IP=$(shell aws lightsail get-instance --instance-name $(INSTANCE_NAME) --query 'instance.publicIpAddress' --output text))
	@echo "Syncing code to $(INSTANCE_NAME) ($(INSTANCE_IP)) as $(SSH_USER) using scp+tar..."
	@tar -czf mcp-server.tar.gz --exclude='.git' --exclude='.venv' --exclude='__pycache__' --exclude='mcp-server.tar.gz' ./ || [ $$? -eq 1 ]
	@scp -i $(KEY_PAIR_NAME).pem -o StrictHostKeyChecking=no mcp-server.tar.gz $(SSH_USER)@$(INSTANCE_IP):/tmp/
	@ssh -i $(KEY_PAIR_NAME).pem -o StrictHostKeyChecking=no $(SSH_USER)@$(INSTANCE_IP) \
		"sudo apt-get update -y && sudo apt-get install -y python3-pip python3-venv && \
		 sudo tar -xzf /tmp/mcp-server.tar.gz -C /opt/mcp-server/ && \
		 sudo chown -R $(SSH_USER):$(SSH_USER) /opt/mcp-server/ && \
		 sudo bash /opt/mcp-server/scripts/setup-instance.sh && \
		 cd /opt/mcp-server && pip3 install -r requirements.txt --break-system-packages && \
		 sudo systemctl restart mcp-server && \
		 sudo systemctl status mcp-server --no-pager"
	@rm mcp-server.tar.gz

aws-destroy: instance-destroy container-destroy

container-destroy:
	@echo "Destroying AWS Lightsail container resources for $(SERVICE_NAME)..."
	@aws lightsail delete-container-service --service-name $(SERVICE_NAME) --region $(AWS_REGION) 2>/dev/null || true

instance-destroy:
	@echo "Destroying AWS Lightsail instance $(INSTANCE_NAME)..."
	@aws lightsail delete-instance --instance-name $(INSTANCE_NAME) --region $(AWS_REGION) 2>/dev/null || true
	@rm -f $(KEY_PAIR_NAME).pem

.PHONY: clean
clean:
	@echo "Cleaning up..."
	@find . -type f -name "*.pyc" -delete
	@find . -type d -name "__pycache__" -exec rm -rf {} +
	@find . -type d -name ".pyte*" -exec rm -rf {} +
	@find . -type d -name ".mypy*" -exec rm -rf {} +
	@rm -rf .venv
