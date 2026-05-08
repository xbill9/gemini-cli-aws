# Configuration - Update these or override via environment variables
AWS_REGION ?= us-east-1
BEDROCK_MODEL ?= amazon.nova-micro-v1:0

install:
	pip install -r requirements.txt

test:
	python test_agent.py

lint:
	ruff check .
	ruff format --check .

clean:
	rm -rf __pycache__
	find . -type d -name ".ruff_cache" -exec rm -rf {} +
	find . -type d -name ".mypy_cache" -exec rm -rf {} +
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.log" -exec rm -rf {} +

# Deploy the Bedrock agent to AWS AgentCore
deploy:
	@echo "🚀 Deploying Bedrock agent to AWS AgentCore..."
	cd bedrocksre && agentcore deploy --yes

# Destroy the Bedrock agent on AWS AgentCore
destroy:
	@echo "🗑️  Destroying Bedrock agent on AWS AgentCore..."
	cd bedrocksre && agentcore stop --yes

status:
	@echo "🔍 Checking status of Bedrock agent..."
	cd bedrocksre && agentcore status

# Get the HTTP URL of the deployed agent
endpoint:
	@cd bedrocksre && agentcore fetch access --name bedrocksregateway --type gateway --json | sed -E 's/\x1B\[\??[0-9;]*[a-zA-Z]//g' | jq -r '.url'

.PHONY: install test clean deploy destroy status endpoint help

help:
	@echo "Bedrock ADK Agent Commands:"
	@echo "  make deploy          - Deploy Bedrock agent to AWS AgentCore"
	@echo "  make destroy         - Stop/Destroy Bedrock agent resources"
	@echo "  make status          - Check deployment status"
	@echo "  make endpoint        - Get the public HTTP URL of the agent"
	@echo "  make test            - Run local tests"
