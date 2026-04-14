# Makefile for AI Course Creator (Multi-Agent System) on AWS ECS Express Mode

# Use the current python3 from environment
PYTHON_CMD ?= $(shell which python3)

# Set PYTHONPATH to include the project root for shared modules
export PYTHONPATH := $(shell pwd):$(PYTHONPATH)

# Environment variables for local development
export LOG_LEVEL = DEBUG
export GENAI_MODEL = gemini-2.5-flash

# AWS Configuration
AWS_REGION ?= us-east-1
ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query "Account" --output text 2>/dev/null)
GEMINI_API_KEY := $(shell [ -f ~/gemini.key ] && cat ~/gemini.key || echo "N/A")

# ECS Express Mode Configuration
SERVICES = researcher judge content-builder orchestrator app
CLUSTER_NAME = default

.PHONY: install start run run-local restart-local local frontend lint test test-researcher test-judge test-content-builder test-orchestrator test-remote deploy destroy aws-destroy status check-local endpoint a2a clean help researcher content-builder judge orchestrator course-creator researcher-local judge-local content-builder-local orchestrator-local backend-local frontend-local agents-local stop-local start-local check-frontend e2e-test e2e-test-ecs ecr-setup ecr-login ecr-push docker-build iam-roles ecs-deploy status-ecs endpoint-ecs

# --- General Targets ---

help:
	@echo "Available commands:"
	@echo "  install               - Install all dependencies for root, agents, and app"
	@echo "  start                 - Start all services locally (alias for start-local)"
	@echo "  stop                  - Stop all local services (alias for stop-local)"
	@echo "  run                   - Start all services locally (alias for start-local)"
	@echo "  local                 - Show local service URLs"
	@echo "  test                  - Run all tests (pytest)"
	@echo "  lint                  - Run linting checks (ruff)"
	@echo "  deploy                - Full deployment to AWS ECS (ECR push + IAM roles + ECS deploy)"
	@echo "  destroy               - Delete all ECS services"
	@echo "  status                - Show ECS service status"
	@echo "  endpoint              - Show app endpoint"
	@echo "  e2e-test-ecs          - Run end-to-end test against ECS endpoint"
	@echo "  clean                 - Remove caches and logs"

install:
	@echo "Installing root dependencies..."
	pip install -e ".[dev,lint]"
	@echo "Installing agent and app dependencies..."
	for dir in agents/* app; do (cd $$dir && pip install -e .); done
	@echo "Installing frontend dependencies..."
	cd app/frontend && npm install

clean:
	@echo "Cleaning up caches and temporary files..."
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type d -name ".pytest_cache" -exec rm -rf {} +
	find . -type d -name ".ruff_cache" -exec rm -rf {} +
	find . -type d -name ".adk" -exec rm -rf {} +
	find . -type f -name "*.log" -delete
	@echo "Clean completed."

# --- Local Development ---

run: start-local
start: start-local
run-local: start-local
restart-local: start-local
stop: stop-local

check-frontend:
	@if [ ! -d "app/dist" ]; then \
		echo "Frontend build missing. Building frontend..."; \
		$(MAKE) frontend; \
	fi

frontend:
	make -C app build-frontend

researcher-local:
	@echo "Starting Researcher agent locally on port 8001..."
	@/bin/bash -c "source .env 2>/dev/null || true; \
	$(PYTHON_CMD) -m shared.adk_app --host 0.0.0.0 --port 8001 --a2a agents/researcher"

judge-local:
	@echo "Starting Judge agent locally on port 8002..."
	@/bin/bash -c "source .env 2>/dev/null || true; \
	$(PYTHON_CMD) -m shared.adk_app --host 0.0.0.0 --port 8002 --a2a agents/judge"

content-builder-local:
	@echo "Starting Content Builder agent locally on port 8003..."
	@/bin/bash -c "source .env 2>/dev/null || true; \
	$(PYTHON_CMD) -m shared.adk_app --host 0.0.0.0 --port 8003 --a2a agents/content_builder"

orchestrator-local:
	@echo "Starting Orchestrator agent locally on port 8004..."
	@/bin/bash -c "source .env 2>/dev/null || true; \
	export RESEARCHER_AGENT_CARD_URL=http://localhost:8001/a2a/researcher/.well-known/agent-card.json; \
	export JUDGE_AGENT_CARD_URL=http://localhost:8002/a2a/judge/.well-known/agent-card.json; \
	export CONTENT_BUILDER_AGENT_CARD_URL=http://localhost:8003/a2a/content_builder/.well-known/agent-card.json; \
	$(PYTHON_CMD) -m shared.adk_app --host 0.0.0.0 --port 8004 agents/orchestrator"

agents-local: stop-local
	@echo "Starting all agents in background..."
	@nohup $(MAKE) researcher-local > researcher.log 2>&1 &
	@nohup $(MAKE) judge-local > judge.log 2>&1 &
	@nohup $(MAKE) content-builder-local > content_builder.log 2>&1 &
	@echo "Waiting for sub-agents to start..."
	@sleep 5
	@nohup $(MAKE) orchestrator-local > orchestrator.log 2>&1 &
	@echo "All agents started."

start-local: check-frontend agents-local
	@echo "Starting App Backend in background..."
	@nohup $(MAKE) backend-local > backend.log 2>&1 &
	@echo "Starting Frontend dev server in background..."
	@nohup $(MAKE) frontend-local > frontend.log 2>&1 &
	@echo "All services started."
	@echo "Frontend: http://localhost:5173"
	@echo "Backend:  http://localhost:8000"

stop-local:
	@echo "Stopping any existing agent and server processes..."
	@pkill -9 -f "[s]hared[.]adk_app" 2>/dev/null || true
	@pkill -9 -f "[m]ain[.]py" 2>/dev/null || true
	@pkill -9 -f "[v]ite" 2>/dev/null || true

backend-local:
	@echo "Starting App Backend locally on port 8000..."
	@/bin/bash -c "source .env 2>/dev/null || true; \
	export AGENT_SERVER_URL=http://localhost:8004; \
	export AGENT_NAME=orchestrator; \
	export PORT=8000; \
	cd app && $(PYTHON_CMD) main.py"

frontend-local:
	@echo "Starting Frontend (Vite) dev server..."
	@/bin/bash -c "cd app/frontend && npm run dev -- --host 0.0.0.0"

local:
	@echo "--- Local Service URLs ---"
	@echo "Frontend: http://localhost:5173"
	@echo "Backend:  http://localhost:8000"
	@echo "Agents: researcher (8001), judge (8002), content-builder (8003), orchestrator (8004)"

# --- Testing ---

lint:
	ruff check .

test:
	python -m pytest

test-researcher:
	./research_test.sh

test-judge:
	./judge_test.sh

test-orchestrator:
	python agents/orchestrator/test_orchestrator.py

TEST_URL ?= http://localhost:8000
TEST_MESSAGE ?= "Create a short course about the history of the internet"
e2e-test:
	@echo "Running end-to-end test against $(TEST_URL)..."
	@curl -s -X POST $(TEST_URL)/api/chat_stream \
		-H "Content-Type: application/json" \
		-d '{"message": $(TEST_MESSAGE), "user_id": "e2e_test_user"}' \
		--no-buffer \
		|| (echo "E2E Test Failed" && exit 1)
	@echo "\nE2E Test Completed successfully!"

e2e-test-ecs:
	@echo "Fetching ECS endpoint..."
	@ENDPOINT=$$(aws ecs describe-express-gateway-service --service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/v2-course-creator --query 'service.activeConfigurations[0].ingressPaths[0].endpoint' --output text 2>/dev/null); \
	if [ -z "$$ENDPOINT" ] || [ "$$ENDPOINT" = "None" ] || [ "$$ENDPOINT" = "null" ]; then \
		echo "Error: ECS endpoint not found."; \
		exit 1; \
	fi; \
	$(MAKE) e2e-test TEST_URL=http://$$ENDPOINT

# --- AWS ECS Deployment (Express Mode) ---

# Primary deploy command
deploy: ecr-push iam-roles ecs-deploy

# Target to show AWS ECS status
status: status-ecs

# Target to get the public endpoint URL
endpoint: endpoint-ecs

# IAM roles for ECS Express Mode
iam-roles:
	@echo "Creating IAM roles for ECS Express Mode..."
	@aws iam get-role --role-name ecsTaskExecutionRole 2>/dev/null || \
                (aws iam create-role --role-name ecsTaskExecutionRole \
                        --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}' && \
                aws iam attach-role-policy --role-name ecsTaskExecutionRole \
                        --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy)
	@aws iam get-role --role-name ecsInfrastructureRoleForExpressServices 2>/dev/null || \
                (aws iam create-role --role-name ecsInfrastructureRoleForExpressServices \
                        --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs.amazonaws.com"},"Action":"sts:AssumeRole"}]}' && \
                aws iam attach-role-policy --role-name ecsInfrastructureRoleForExpressServices \
                        --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRoleforExpressGatewayServices)

# ECR setup and push for all services
ecr-setup:
	@echo "Ensuring ECR repositories exist..."
	@for service in $(SERVICES); do \
		REPO_NAME=ai-course-creator-$$service; \
		aws ecr describe-repositories --repository-names $$REPO_NAME --region $(AWS_REGION) 2>/dev/null || \
			aws ecr create-repository --repository-name $$REPO_NAME --region $(AWS_REGION); \
	done

ecr-login:
	@echo "Logging into ECR..."
	@aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

docker-build:
	@echo "Building Docker images..."
	@for service in researcher judge content-builder orchestrator app; do \
		DIR=$$service; \
		[ "$$service" = "content-builder" ] && DIR=content_builder; \
		REPO_NAME=ai-course-creator-$$service; \
		echo "Building $$service..."; \
		if [ "$$service" = "app" ]; then \
			docker build -t $$REPO_NAME -f ./app/Dockerfile .; \
		else \
			docker build -t $$REPO_NAME -f ./agents/$$DIR/Dockerfile .; \
		fi; \
	done

ecr-push: ecr-setup ecr-login docker-build
	@echo "Pushing images to ECR..."
	@for service in $(SERVICES); do \
		REPO_NAME=ai-course-creator-$$service; \
		ECR_URI=$(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$$REPO_NAME:latest; \
		docker tag $$REPO_NAME:latest $$ECR_URI; \
		docker push $$ECR_URI; \
	done

# ECS Express Mode Deployment logic
ecs-deploy:
	@echo "Deploying to ECS Express Mode..."
	@./ecs/deploy-express.sh

# Target to show AWS ECS status
status-ecs:
	@echo "Checking AWS ECS service status..."
	@for service in researcher judge content-builder orchestrator course-creator; do \
		echo "Status for v2-$$service:"; \
		aws ecs describe-express-gateway-service --service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/v2-$$service 2>/dev/null | \
			python3 -c "import sys, json; data = json.load(sys.stdin); s = data['service']; \
			status = s['status']['statusCode']; \
			endpoint = s['activeConfigurations'][0]['ingressPaths'][0]['endpoint'] if s.get('activeConfigurations') else 'N/A'; \
			print(f\"  Status: {status}\n  Endpoint: {endpoint}\")" || \
			echo "  Service v2-$$service not found."; \
	done

# Target to get the public endpoint URL
endpoint-ecs:
	@aws ecs describe-express-gateway-service --service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/v2-course-creator \
		--query 'service.activeConfigurations[0].ingressPaths[0].endpoint' --output text 2>/dev/null || echo "N/A"

# Destroy AWS resources
destroy: aws-destroy

aws-destroy:
	@echo "Destroying AWS ECS Express services..."
	@for service in researcher judge content-builder orchestrator course-creator; do \
		echo "Deleting service v2-$$service..."; \
		aws ecs delete-express-gateway-service --service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/v2-$$service 2>/dev/null || true; \
	done
	@echo "AWS resources destroyed."
