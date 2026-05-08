# AWS Bedrock AgentCore Deployment Makefile

.PHONY: build deploy status stop dev help

# Build/Package the agent code
build:
	@echo "📦 Packaging agent code..."
	agentcore package

# Deploy the infrastructure and agent to AWS
deploy:
	@echo "🚀 Deploying to AWS Bedrock AgentCore..."
	agentcore deploy --yes

# Check the status of deployed resources
status:
	@echo "🔍 Checking AgentCore status..."
	agentcore status

# Stop/Destroy the deployed resources
stop:
	@echo "🗑️  Stopping AgentCore resources..."
	agentcore stop --yes

# Run the agent locally for development
dev:
	@echo "🛠 Starting local development server..."
	agentcore dev

help:
	@echo "AWS Bedrock AgentCore Deployment Targets:"
	@echo "  make build   - Package the agent code"
	@echo "  make deploy  - Deploy infrastructure and agent to AWS"
	@echo "  make status  - Check status of deployed resources"
	@echo "  make stop    - Destroy deployed resources"
	@echo "  make dev     - Run agent locally for development"
