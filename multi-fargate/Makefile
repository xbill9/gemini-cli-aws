# Makefile for AI Course Creator (Multi-Agent System)

# Use the current python3 from environment
PYTHON_CMD ?= $(shell which python3)

# Set PYTHONPATH to include the project root for shared modules
export PYTHONPATH := $(shell pwd):$(PYTHONPATH)

# Environment variables for local development
export LOG_LEVEL = DEBUG
export GENAI_MODEL = gemini-2.5-flash

.PHONY: install start run run-local restart-local local frontend lint test test-researcher test-judge test-content-builder test-orchestrator researcher content-builder judge orchestrator course-creator researcher-local judge-local content-builder-local orchestrator-local backend-local frontend-local agents-local stop-local start-local check-frontend build-images deploy-fargate destroy-fargate aws-destroy fargate-status status-fargate endpoint-fargate clean help e2e-test e2e-test-fargate

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
	@echo "  e2e-test              - Run end-to-end test against localhost"
	@echo "  e2e-test-fargate      - Run end-to-end test against Fargate endpoint"
	@echo "  lint                  - Run linting checks (ruff)"
	@echo "  deploy-fargate        - Deploy all services to AWS Fargate"
	@echo "  setup-fargate         - Provision AWS Fargate infrastructure"
	@echo "  destroy-fargate       - Delete Fargate resources"
	@echo "  aws-destroy           - Delete Fargate resources (alias for destroy-fargate)"
	@echo "  status-fargate        - Show Fargate status"
	@echo "  fargate-status        - Show Fargate status (alias for status-fargate)"
	@echo "  endpoint-fargate      - Show Fargate service endpoint"
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

e2e-test-fargate:
	@echo "Fetching Fargate endpoint..."
	@TASK_ARN=$$(aws ecs list-tasks --cluster adk-fargate-cluster --service-name adk-fargate-service --region us-east-1 --query 'taskArns[0]' --output text); \
	if [ "$$TASK_ARN" = "None" ] || [ -z "$$TASK_ARN" ]; then \
		echo "Error: No running tasks found."; \
		exit 1; \
	fi; \
	ENI_ID=$$(aws ecs describe-tasks --cluster adk-fargate-cluster --tasks $$TASK_ARN --region us-east-1 --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text); \
	PUBLIC_IP=$$(aws ec2 describe-network-interfaces --network-interface-ids $$ENI_ID --region us-east-1 --query 'NetworkInterfaces[0].Association.PublicIp' --output text); \
	if [ "$$PUBLIC_IP" = "None" ] || [ -z "$$PUBLIC_IP" ]; then \
		echo "Error: No public IP associated with the task."; \
		exit 1; \
	fi; \
	$(MAKE) e2e-test TEST_URL=http://$$PUBLIC_IP:8080

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

.PHONY: install start run run-local restart-local local frontend lint test test-researcher test-judge test-content-builder test-orchestrator researcher content-builder judge orchestrator course-creator researcher-local judge-local content-builder-local orchestrator-local backend-local frontend-local agents-local stop-local start-local check-frontend build-images deploy-fargate setup-fargate destroy-fargate aws-destroy fargate-status status-fargate endpoint-fargate clean help e2e-test e2e-test-fargate

deploy: deploy-fargate

deploy-fargate:
	chmod +x *.sh 2>/dev/null || true
	./deploy-fargate.sh

setup-fargate:
	chmod +x *.sh 2>/dev/null || true
	./setup-fargate.sh

destroy-fargate: aws-destroy

aws-destroy:
	@echo "Destroying AWS resources for adk-fargate..."
	@aws ecs update-service --cluster adk-fargate-cluster --service adk-fargate-service --desired-count 0 --region us-east-1 2>/dev/null || true
	@aws ecs delete-service --cluster adk-fargate-cluster --service adk-fargate-service --force --region us-east-1 2>/dev/null || true
	@aws ecs delete-cluster --cluster adk-fargate-cluster --region us-east-1 2>/dev/null || true
	@aws ecr delete-repository --repository-name adk-course-creator --region us-east-1 --force 2>/dev/null || true
	@echo "AWS resources destroyed."

fargate-status: status-fargate

status-fargate:
	@aws ecs describe-services --cluster adk-fargate-cluster --services adk-fargate-service --region us-east-1 \
		--query 'services[0].{Name:serviceName, Status:status, Desired:desiredCount, Running:runningCount, TaskDef:taskDefinition}' \
		--output table

endpoint-fargate:
	@TASK_ARN=$$(aws ecs list-tasks --cluster adk-fargate-cluster --service-name adk-fargate-service --region us-east-1 --query 'taskArns[0]' --output text); \
	if [ "$$TASK_ARN" != "None" ] && [ -n "$$TASK_ARN" ]; then \
		ENI_ID=$$(aws ecs describe-tasks --cluster adk-fargate-cluster --tasks $$TASK_ARN --region us-east-1 --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text); \
		PUBLIC_IP=$$(aws ec2 describe-network-interfaces --network-interface-ids $$ENI_ID --region us-east-1 --query 'NetworkInterfaces[0].Association.PublicIp' --output text); \
		if [ "$$PUBLIC_IP" != "None" ] && [ -n "$$PUBLIC_IP" ]; then \
			echo "Fargate Endpoint: http://$$PUBLIC_IP:8080"; \
		else \
			echo "No public IP associated with the task."; \
		fi \
	else \
		echo "No running tasks found."; \
	fi

status: status-fargate

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

endpoint: endpoint-fargate

clean:
	@echo "Cleaning up caches and temporary files..."
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type d -name ".pytest_cache" -exec rm -rf {} +
	find . -type d -name ".ruff_cache" -exec rm -rf {} +
	find . -type d -name ".adk" -exec rm -rf {} +
	find . -type f -name "*.log" -delete
	@echo "Clean completed."
