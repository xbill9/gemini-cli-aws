# Makefile for AI Course Creator (Multi-Agent System)

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
CLUSTER_NAME = multi-agent-cluster

.PHONY: install start run run-local restart-local local frontend lint test test-researcher test-judge test-content-builder test-orchestrator test-remote deploy destroy status check-local endpoint a2a clean help researcher content-builder judge orchestrator course-creator researcher-local judge-local content-builder-local orchestrator-local backend-local frontend-local agents-local stop-local start-local check-frontend build-images deploy-ecs destroy-ecs status-ecs endpoint-ecs e2e-test-ecs iam-roles ecr-setup ecr-login ecr-push ecs-deploy-express

help:
	@echo "Available commands:"
	@echo "  install               - Install all dependencies for root, agents, and app"
	@echo "  start                 - Start all services locally (alias for start-local)"
	@echo "  stop                  - Stop all local services (alias for stop-local)"
	@echo "  run                   - Start all services locally (alias for start-local)"
	@echo "  local                 - Show local service URLs"
	@echo "  start-local           - Start all local services in background"
	@echo "  stop-local            - Stop all local processes"
	@echo "  test                  - Run all tests (pytest)"
	@echo "  test-researcher       - Test the Researcher agent directly"
	@echo "  test-judge            - Test the Judge agent directly"
	@echo "  test-orchestrator     - Test the Orchestrator logic"
	@echo "  lint                  - Run linting checks (ruff)"
	@echo "  iam-roles             - Create IAM roles for ECS Express Mode"
	@echo "  deploy-ecs            - Deploy all services to AWS ECS (Express Mode)"
	@echo "  destroy-ecs           - Delete ECS services"
	@echo "  status-ecs            - Show ECS status"
	@echo "  endpoint-ecs          - Show ECS service public IP/Endpoint"
	@echo "  e2e-test-ecs          - Run end-to-end test against ECS endpoint"
	@echo "  clean                 - Remove caches and logs"

TEST_URL ?= http://localhost:8000
TEST_MESSAGE ?= "Create a short course about the history of the internet"
e2e-test:
	@echo "Running end-to-end test against $(TEST_URL)..."
	@curl -s -X POST $(TEST_URL)/api/chat_stream \
		-H "Content-Type: application/json" \
		-d '{"message": $(TEST_MESSAGE), "user_id": "e2e_test_user"}' \
		--no-buffer \
		|| (echo "E2E Test Failed: No valid response from $(TEST_URL)" && exit 1)
	@echo "\nE2E Test Completed successfully!"

e2e-test-ecs:
	@echo "Fetching ECS endpoint..."
	@ENDPOINT=$$(aws ecs describe-express-gateway-service --service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/course-creator --query 'service.activeConfigurations[0].ingressPaths[0].endpoint' --output text 2>/dev/null); \
	if [ -z "$$ENDPOINT" ] || [ "$$ENDPOINT" = "None" ] || [ "$$ENDPOINT" = "null" ]; then \
		echo "Error: ECS endpoint not found or service is still provisioning."; \
		exit 1; \
	fi; \
	$(MAKE) e2e-test TEST_URL=http://$$ENDPOINT

install:
	@echo "Installing root dependencies..."
	pip install -e ".[dev,lint]"
	@echo "Installing agent and app dependencies..."
	for dir in agents/* app; do (cd $$dir && pip install -e .); done
	@echo "Installing frontend dependencies..."
	cd app/frontend && npm install

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
	@echo "All agents started. Logs: researcher.log, judge.log, content_builder.log, orchestrator.log"

start-local: check-frontend agents-local
	@echo "Starting App Backend in background..."
	@nohup $(MAKE) backend-local > backend.log 2>&1 &
	@echo "Starting Frontend dev server in background..."
	@nohup $(MAKE) frontend-local > frontend.log 2>&1 &
	@echo "All services started. Logs: researcher.log, judge.log, content_builder.log, orchestrator.log, backend.log, frontend.log"
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

frontend:
	make -C app build-frontend

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

test-content-builder:
	python agents/content_builder/tests/test_agent.py

deploy: deploy-ecs

deploy-ecs: iam-roles
	./ecs/deploy-express.sh

destroy-ecs:
	@echo "Destroying ECS Express services in cluster default..."
	@for service in researcher judge content-builder orchestrator course-creator; do \
		echo "Deleting service $$service..."; \
		aws ecs delete-express-gateway-service --service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/$$service 2>/dev/null || true; \
	done
	@echo "Destroy completed."

status-ecs:
	@echo "--- ECS Express Services Status ---"
	@for service in researcher judge content-builder orchestrator course-creator; do \
		echo "Status for $$service:"; \
		aws ecs describe-express-gateway-service --service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/$$service --query 'service.{Name:serviceName, Status:status.statusCode, Endpoint:activeConfigurations[0].ingressPaths[0].endpoint}' --output table 2>/dev/null || echo "Service $$service not found."; \
	done

endpoint-ecs:
	@echo "--- AWS ECS Endpoint (course-creator) ---"
	@aws ecs describe-express-gateway-service --service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/course-creator --query 'service.activeConfigurations[0].ingressPaths[0].endpoint' --output text 2>/dev/null || echo "Pending or not found..."

iam-roles:
	@echo "Creating IAM roles for ECS Express Mode..."
	@# Task Execution Role
	@aws iam get-role --role-name ecsTaskExecutionRole 2>/dev/null || \
                (aws iam create-role --role-name ecsTaskExecutionRole \
                        --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}' && \
                aws iam attach-role-policy --role-name ecsTaskExecutionRole \
                        --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy)
	@# Infrastructure Role
	@aws iam get-role --role-name ecsInfrastructureRoleForExpressServices 2>/dev/null || \
                (aws iam create-role --role-name ecsInfrastructureRoleForExpressServices \
                        --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs.amazonaws.com"},"Action":"sts:AssumeRole"}]}' && \
                aws iam attach-role-policy --role-name ecsInfrastructureRoleForExpressServices \
                        --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRoleforExpressGatewayServices)

local:
	@echo "--- Local Service URLs ---"
	@echo "Frontend: http://localhost:5173"
	@echo "Backend:  http://localhost:8000 (main app)"
	@echo "Agents:"
	@echo "  Researcher:      http://localhost:8001"
	@echo "  Judge:           http://localhost:8002"
	@echo "  Content Builder: http://localhost:8003"
	@echo "  Orchestrator:    http://localhost:8004"

check-local:
	@echo "Checking status of locally running agents and servers..."
	@echo "--- Network Status ---"
	@netstat -tulnp 2>/dev/null | grep -E "8000|8001|8002|8003|8004|5173" || echo "No services listening on expected ports (8000-8004, 5173)."
	@echo "--- Process Status ---"
	@ps aux | grep -E "[s]hared[.]adk_app|[m]ain[.]py|[v]ite" || echo "No matching processes found."

clean:
	@echo "Cleaning up caches and temporary files..."
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type d -name ".pytest_cache" -exec rm -rf {} +
	find . -type d -name ".ruff_cache" -exec rm -rf {} +
	find . -type d -name ".adk" -exec rm -rf {} +
	find . -type f -name "*.log" -delete
	@echo "Clean completed."

