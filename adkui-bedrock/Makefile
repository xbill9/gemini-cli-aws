export AWS_PAGER :=
# Makefile for adk-bedrock-python-aws (AgentCore)

# Include and export AWS credentials if they exist
-include .aws_creds
export

# AWS Configuration
AWS_REGION ?= us-east-1
AWS_ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null)

# Default target
all: install lint format type-check

.PHONY: all install run test lint format type-check status git-status pull push clean deploy agentcore-deploy agentcore-dev agentcore-status agentcore-logs web

# Installation and Execution
install:
	@echo "Installing dependencies..."
	pip install .
	cd agentcore/cdk && npm install

run:
	@echo "Running the ADK Studio locally..."
	python app/fast_api_app.py

web:
	@echo "Launching ADK Web UI (playground)..."
	uvx google-agents-cli playground

# Code Quality and Testing
lint:
	@echo "Running linting (flake8)..."
	flake8 app --exclude .venv

format:
	@echo "Formatting code (black)..."
	black app

type-check:
	@echo "Running type checking (mypy)..."
	PYTHONPATH=. mypy app

test:
	@echo "Running tests (pytest)..."
	PYTHONPATH=. pytest tests

# AgentCore Commands
deploy: agentcore-deploy

agentcore-deploy:
	@echo "Deploying to AgentCore..."
	agentcore deploy

agentcore-dev:
	@echo "Starting AgentCore local development..."
	agentcore dev

agentcore-status:
	@echo "Showing AgentCore status..."
	agentcore status

agentcore-logs:
	@echo "Streaming AgentCore logs..."
	agentcore logs

# Monitoring
status: agentcore-status

endpoint:
	@echo "Fetching project endpoints..."
	@echo "--- ADK Studio Endpoint ---"
	@agentcore status | grep -A 2 "adk_studio:" || true

# Target to show git status
git-status:
	@echo "Showing git status..."
	@git status

# Target to pull latest changes from git
pull:
	@echo "Pulling latest changes from git..."
	@git pull

# Target to push changes to git
push:
	@echo "Pushing changes to git..."
	@git push

.PHONY: clean
clean:
	@echo "Cleaning up..."
	@find . -type f -name "*.pyc" -delete
	@find . -type d -name "__pycache__" -exec rm -rf {} +
	@find . -type d -name ".pyte*" -exec rm -rf {} +
	@find . -type d -name ".mypy*" -exec rm -rf {} +
	@rm -rf .venv
	@rm -f task-definition.json
