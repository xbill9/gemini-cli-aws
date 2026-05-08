# Makefile for AI Course Creator (Multi-Agent System)
export AWS_PAGER :=

# Use the current python3 from environment
PYTHON_CMD ?= $(shell which python3)

# Set PYTHONPATH to include the project root for shared modules
export PYTHONPATH := $(shell pwd):$(PYTHONPATH)

# Environment variables for local development
export LOG_LEVEL = DEBUG
export GENAI_MODEL = gemini-2.5-flash

.PHONY: install start run run-local restart-local local local-status frontend lint test test-researcher test-judge test-content-builder test-orchestrator researcher content-builder judge orchestrator course-creator researcher-local judge-local content-builder-local orchestrator-local backend-local frontend-local agents-local stop-local start-local check-frontend build-images clean help e2e-test deploy-lightsail lightsail-status endpoint-lightsail destroy-lightsail e2e-test-lightsail

help:
	@echo "Available commands:"
	@echo "  install               - Install all dependencies for root, agents, and app"
	@echo "  start                 - Start all services locally (alias for start-local)"
	@echo "  stop                  - Stop all local services (alias for stop-local)"
	@echo "  run                   - Start all services locally (alias for start-local)"
	@echo "  local                 - Show local service URLs"
	@echo "  local-status          - Check status of local processes"
	@echo "  start-local           - Start all local services in background"
	@echo "  stop-local            - Stop all local processes"
	@echo "  test                  - Run all tests (pytest)"
	@echo "  e2e-test              - Run end-to-end test against localhost"
	@echo "  e2e-test-lightsail    - Run end-to-end test against Lightsail endpoint"
	@echo "  lint                  - Run linting checks (ruff)"
	@echo "  deploy                - Deploy all services to AWS Lightsail"
	@echo "  status                - Show Lightsail service status"
	@echo "  endpoint              - Show Lightsail service endpoint"
	@echo "  destroy               - Delete Lightsail service"
	@echo "  deploy-lightsail      - Deploy all services to AWS Lightsail"
	@echo "  lightsail-status      - Show Lightsail service status"
	@echo "  endpoint-lightsail    - Show Lightsail service endpoint"
	@echo "  destroy-lightsail     - Delete Lightsail service"
	@echo "  clean                 - Remove caches and logs"

TEST_URL ?= http://localhost:8000
TEST_MESSAGE ?= Create a short course about the history of the internet
e2e-test:
	@echo "Running end-to-end test against $(TEST_URL)..."
	@TEMP_JSON_FILE=$$(mktemp); \
	_TEST_URL=$$(echo "$(TEST_URL)" | sed 's/\/\?$$//'); \
	echo '{"message": "$(TEST_MESSAGE)", "user_id": "e2e_test_user"}' > $$TEMP_JSON_FILE; \
	echo "Temporary JSON file content: $$(cat $$TEMP_JSON_FILE)"; \
	echo "Executing: curl -s -X POST $$_TEST_URL/api/chat_stream -H \"Content-Type: application/json\" -d @$$TEMP_JSON_FILE --no-buffer"; \
	curl -s -f -X POST $$_TEST_URL/api/chat_stream \
		-H "Content-Type: application/json" \
		-d @$$TEMP_JSON_FILE \
		--no-buffer; \
	CURL_EXIT_CODE=$$?; \
	rm $$TEMP_JSON_FILE; \
	if [ $$CURL_EXIT_CODE -ne 0 ]; then \
		echo "E2E Test Failed: curl exited with code $$CURL_EXIT_CODE"; \
		exit 1; \
	fi
	@echo "\nE2E Test Completed successfully!"

e2e-test-lightsail:
	@echo "Fetching Lightsail endpoint..."
	@ENDPOINT=$$(make endpoint-lightsail); \
	if [ -z "$$ENDPOINT" ]; then \
		echo "Error: Lightsail endpoint not found. Check if the service is deployed."; \
		exit 1; \
	fi; \
	$(MAKE) e2e-test TEST_URL=$$ENDPOINT

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

.PHONY: deploy-agentcore agentcore-status agentcore-logs agentcore-dev

deploy-agentcore:
	@echo "Deploying to Amazon Bedrock AgentCore..."
	agentcore deploy

agentcore-status:
	agentcore status

agentcore-logs:
	agentcore logs

agentcore-dev:
	agentcore dev

deploy: deploy-agentcore

deploy-lightsail:
	chmod +x lightsail/deploy-lightsail.sh
	./lightsail/deploy-lightsail.sh

destroy-lightsail:
	@echo "Destroying Lightsail service..."
	aws lightsail delete-container-service --service-name course-creator-service --region us-east-1 || true

lightsail-status:
	@aws lightsail get-container-services --service-name course-creator-service --region us-east-1 \
		--query 'containerServices[0].{State:state, Deployment:currentDeployment.state, URL:publicEndpoint.url}' \
		--output table

endpoint-lightsail:
	@aws lightsail get-container-services --service-name course-creator-service --region us-east-1 \
                --query 'containerServices[0].url' \
                --output text

status: lightsail-status

local:
	@echo "--- Local Service URLs ---"
	@echo "Frontend: http://localhost:5173"
	@echo "Backend:  http://localhost:8000 (main app)"
	@echo "Agents:"
	@echo "  Researcher:      http://localhost:8001"
	@echo "  Judge:           http://localhost:8002"
	@echo "  Content Builder: http://localhost:8003"
	@echo "  Orchestrator:    http://localhost:8004"

status-local: check-local
local-status: check-local

check-local:
	@echo "Checking status of locally running agents and servers..."
	@echo "--- Network Status ---"
	@netstat -tulnp 2>/dev/null | grep -E "8000|8001|8002|8003|8004|5173" || echo "No services listening on expected ports (8000-8004, 5173)."
	@echo "--- Process Status ---"
	@ps aux | grep -E "[s]hared[.]adk_app|[m]ain[.]py|[v]ite" || echo "No matching processes found."

endpoint: endpoint-lightsail

clean:
	@echo "Cleaning up caches and temporary files..."
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type d -name ".pytest_cache" -exec rm -rf {} +
	find . -type d -name ".ruff_cache" -exec rm -rf {} +
	find . -type d -name ".adk" -exec rm -rf {} +
	find . -type f -name "*.log" -delete
	@echo "Clean completed."
