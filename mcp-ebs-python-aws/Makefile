export AWS_PAGER :=
# Makefile for mcp-ebs-python-aws (Elastic Beanstalk)

# Include and export AWS credentials if they exist
-include .aws_creds
export

# AWS Configuration
AWS_REGION ?= us-east-1
SERVICE_NAME ?= mcp-server-eb
EB_ENV_NAME := $(SERVICE_NAME)-env

.PHONY: all install run build test lint format type-check status git-status eb-status endpoint clean deploy docker-build aws-destroy

all: install run

# Install dependencies
install:
	pip install -r requirements.txt

# Run the server locally
run:
	python main.py

# Target to show both git and EB status
status: eb-status

# Target to show git status
git-status:
	@echo "Showing git status..."
	@git status

# Target to show AWS Elastic Beanstalk status
eb-status:
	@echo "Elastic Beanstalk Status ($$EB_ENV_NAME):"
	@eb status $(EB_ENV_NAME) --region $(AWS_REGION) || echo "EB environment not found."
	@echo "\nRecent Events:"
	@eb events $(EB_ENV_NAME) --region $(AWS_REGION) | head -n 20

# Target to get the public endpoint URL (Elastic Beanstalk)
endpoint:
	@eb status $(EB_ENV_NAME) --region $(AWS_REGION) | grep "CNAME" | awk '{print "http://" $$2}'

# Code Quality targets
test:
	@echo "Running tests..."
	@export PYTHONPATH=$${PYTHONPATH}:. && python -m pytest tests/test_main.py

lint:
	@echo "Running flake8..."
	@flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics
	@flake8 . --count --exit-zero --max-complexity=10 --max-line-length=127 --statistics

format:
	@echo "Running black formatting..."
	@black . || echo "Black not installed, skipping."

# Build the Docker image locally for testing
docker-build:
	@echo "Building the Docker image..."
	@docker build -t $(SERVICE_NAME) .

# Deploy to Amazon Elastic Beanstalk
deploy:
	@./deploy.sh

aws-destroy:
	@./destroy.sh

.PHONY: clean
clean:
	@echo "Cleaning up..."
	@find . -type f -name "*.pyc" -delete
	@find . -type d -name "__pycache__" -exec rm -rf {} +
	@find . -type d -name ".pyte*" -exec rm -rf {} +
	@find . -type d -name ".mypy*" -exec rm -rf {} +
	@rm -rf .venv .elasticbeanstalk
