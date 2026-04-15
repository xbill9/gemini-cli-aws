# Makefile for AI Course Creator (Multi-Agent System) - Distributed ECS Express Mode

SHELL = /bin/bash
export AWS_PAGER :=

# Include and export AWS credentials if they exist
-include .aws_creds
export

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

# Service Names
RESEARCHER_SVC = adk-researcher
JUDGE_SVC = adk-judge
CONTENT_BUILDER_SVC = adk-content-builder
ORCHESTRATOR_SVC = adk-orchestrator
APP_SVC = adk-course-creator

.PHONY: clean test lint deploy run local status aws-destroy ecr-setup ecr-login ecr-push ecs-deploy-all iam-roles credentials help install start stop run-local restart-local start-local check-frontend researcher-local judge-local content-builder-local orchestrator-local agents-local backend-local frontend-local stop-local e2e-test check-local endpoint e2e-test-ecsexpress status-ecsexpress endpoint-ecsexpress

# IAM roles for ECS Express Mode
iam-roles: credentials
	@echo "Creating IAM roles for ECS Express Mode..."
	@aws iam get-role --role-name ecsTaskExecutionRole 2>/dev/null || (aws iam create-role --role-name ecsTaskExecutionRole --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}' && aws iam attach-role-policy --role-name ecsTaskExecutionRole --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy)
	@aws iam get-role --role-name ecsInfrastructureRoleForExpressServices 2>/dev/null || (aws iam create-role --role-name ecsInfrastructureRoleForExpressServices --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs.amazonaws.com"},"Action":"sts:AssumeRole"}]}' && aws iam attach-role-policy --role-name ecsInfrastructureRoleForExpressServices --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRoleforExpressGatewayServices)

# ECR setup and push for all 5 images
ecr-setup:
	@for repo in $(RESEARCHER_SVC) $(JUDGE_SVC) $(CONTENT_BUILDER_SVC) $(ORCHESTRATOR_SVC) $(APP_SVC); do \
		echo "Ensuring ECR repository exists for $$repo..."; \
		aws ecr describe-repositories --repository-names $$repo --region $(AWS_REGION) 2>/dev/null || aws ecr create-repository --repository-name $$repo --region $(AWS_REGION); \
	done

ecr-login:
	@echo "Logging into ECR..."
	@aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

ecr-push: ecr-setup ecr-login
	@echo "Building and pushing 5 images to ECR..."
	@# Researcher
	docker build -t $(RESEARCHER_SVC) -f agents/researcher/Dockerfile .
	docker tag $(RESEARCHER_SVC) $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(RESEARCHER_SVC):latest
	docker push $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(RESEARCHER_SVC):latest
	@# Judge
	docker build -t $(JUDGE_SVC) -f agents/judge/Dockerfile .
	docker tag $(JUDGE_SVC) $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(JUDGE_SVC):latest
	docker push $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(JUDGE_SVC):latest
	@# Content Builder
	docker build -t $(CONTENT_BUILDER_SVC) -f agents/content_builder/Dockerfile .
	docker tag $(CONTENT_BUILDER_SVC) $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(CONTENT_BUILDER_SVC):latest
	docker push $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(CONTENT_BUILDER_SVC):latest
	@# Orchestrator
	docker build -t $(ORCHESTRATOR_SVC) -f agents/orchestrator/Dockerfile .
	docker tag $(ORCHESTRATOR_SVC) $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ORCHESTRATOR_SVC):latest
	docker push $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ORCHESTRATOR_SVC):latest
	@# Web App
	docker build -t $(APP_SVC) -f app/Dockerfile .
	docker tag $(APP_SVC) $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(APP_SVC):latest
	docker push $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(APP_SVC):latest

# Distributed ECS Express Mode Deployment
credentials:
	./save-aws-creds.sh

deploy: credentials iam-roles ecr-push ecs-deploy-all

# Monolith Deployment (recommended for single endpoint)
deploy-monolith: credentials iam-roles ecr-push ecs-deploy-monolith

ecs-deploy-monolith:
	@echo "Deploying Monolith (all-in-one) Web App..."
	@jq -n \
		--arg image "$(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(APP_SVC):latest" \
		--arg project "$(subst ",,$(GOOGLE_CLOUD_PROJECT))" \
		--arg api_key "$(subst ",,$(GOOGLE_API_KEY))" \
		--arg model_id "$(subst ",,$(GENAI_MODEL))" \
		'{image: $$image, containerPort: 8080, command: ["/app/run_monolith.sh"], environment: [{name: "GOOGLE_CLOUD_PROJECT", value: $$project}, {name: "GOOGLE_API_KEY", value: $$api_key}, {name: "GENAI_MODEL", value: $$model_id}, {name: "PORT", value: "8080"}, {name: "AGENT_SERVER_URL", value: "http://localhost:8004"}, {name: "AGENT_NAME", value: "orchestrator"}]}' > primary.json
	@$(MAKE) ecs-execute-deploy SVC=$(APP_SVC)
	@rm primary.json

# Load environment variables for deployment
-include .env
export

ecs-deploy-all:
	@chmod +x get_ecs_endpoint.sh
	@echo "Deploying sub-agents to ECS Express Mode..."
	@# Deploy sub-agents first to get endpoints
	$(MAKE) ecs-deploy-svc SVC=$(RESEARCHER_SVC) PORT=8000
	$(MAKE) ecs-deploy-svc SVC=$(JUDGE_SVC) PORT=8000
	$(MAKE) ecs-deploy-svc SVC=$(CONTENT_BUILDER_SVC) PORT=8000
	@echo "Fetching sub-agent endpoints and deploying Orchestrator..."
	@R_URL=$$(./get_ecs_endpoint.sh $(RESEARCHER_SVC)); \
	J_URL=$$(./get_ecs_endpoint.sh $(JUDGE_SVC)); \
	C_URL=$$(./get_ecs_endpoint.sh $(CONTENT_BUILDER_SVC)); \
	echo "Researcher: https://$$R_URL"; \
	echo "Judge:      https://$$J_URL"; \
	echo "Content:    https://$$C_URL"; \
	$(MAKE) ecs-deploy-orchestrator R_URL=https://$$R_URL J_URL=https://$$J_URL C_URL=https://$$C_URL; \
	echo "Fetching Orchestrator endpoint and deploying Web App..."; \
	O_URL=$$(./get_ecs_endpoint.sh $(ORCHESTRATOR_SVC)); \
	echo "Orchestrator: https://$$O_URL"; \
	$(MAKE) ecs-deploy-app O_URL=https://$$O_URL

ecs-deploy-svc:
	@echo "Deploying $(SVC) on port $(PORT)..."
	@jq -n \
		--arg image "$(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(SVC):latest" \
		--arg project "$(subst ",,$(GOOGLE_CLOUD_PROJECT))" \
		--arg api_key "$(subst ",,$(GOOGLE_API_KEY))" \
		--arg model_id "$(subst ",,$(GENAI_MODEL))" \
		--arg port "$(PORT)" \
		'{image: $$image, containerPort: ($$port | tonumber), environment: [{name: "GOOGLE_CLOUD_PROJECT", value: $$project}, {name: "GOOGLE_API_KEY", value: $$api_key}, {name: "GENAI_MODEL", value: $$model_id}, {name: "PORT", value: $$port}]}' > primary.json
	@$(MAKE) ecs-execute-deploy SVC=$(SVC)
	@rm primary.json

ecs-deploy-orchestrator:
	@echo "Deploying Orchestrator with remote sub-agents..."
	@jq -n \
		--arg image "$(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ORCHESTRATOR_SVC):latest" \
		--arg project "$(subst ",,$(GOOGLE_CLOUD_PROJECT))" \
		--arg api_key "$(subst ",,$(GOOGLE_API_KEY))" \
		--arg model_id "$(subst ",,$(GENAI_MODEL))" \
		--arg r_url "$(R_URL)/a2a/researcher/.well-known/agent-card.json" \
		--arg j_url "$(J_URL)/a2a/judge/.well-known/agent-card.json" \
		--arg c_url "$(C_URL)/a2a/content_builder/.well-known/agent-card.json" \
		'{image: $$image, containerPort: 8000, environment: [{name: "GOOGLE_CLOUD_PROJECT", value: $$project}, {name: "GOOGLE_API_KEY", value: $$api_key}, {name: "GENAI_MODEL", value: $$model_id}, {name: "PORT", value: "8000"}, {name: "RESEARCHER_AGENT_CARD_URL", value: $$r_url}, {name: "JUDGE_AGENT_CARD_URL", value: $$j_url}, {name: "CONTENT_BUILDER_AGENT_CARD_URL", value: $$c_url}]}' > primary.json
	@$(MAKE) ecs-execute-deploy SVC=$(ORCHESTRATOR_SVC)
	@rm primary.json

ecs-deploy-app:
	@echo "Deploying Web App pointing to Orchestrator..."
	@O_BASE_URL=$$(echo "$(O_URL)" | sed 's/\/a2a\/orchestrator//'); \
	jq -n \
		--arg image "$(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(APP_SVC):latest" \
		--arg project "$(subst ",,$(GOOGLE_CLOUD_PROJECT))" \
		--arg api_key "$(subst ",,$(GOOGLE_API_KEY))" \
		--arg o_url "$$O_BASE_URL" \
		'{image: $$image, containerPort: 8080, environment: [{name: "GOOGLE_CLOUD_PROJECT", value: $$project}, {name: "GOOGLE_API_KEY", value: $$api_key}, {name: "PORT", value: "8080"}, {name: "AGENT_SERVER_URL", value: $$o_url}, {name: "AGENT_NAME", value: "orchestrator"}]}' > primary.json
	@$(MAKE) ecs-execute-deploy SVC=$(APP_SVC)
	@rm primary.json

ecs-execute-deploy:
	@PRIMARY_JSON=$$(jq -c . primary.json); \
	DESC=$$(aws ecs describe-express-gateway-service --service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/$(SVC) 2>/dev/null); \
	if [ $$? -eq 0 ]; then \
		echo "Updating existing service $(SVC)..."; \
		SGS=$$(echo $$DESC | jq -r ".service.activeConfigurations[0].networkConfiguration.securityGroups | join(\",\")"); \
		SUBS=$$(echo $$DESC | jq -r ".service.activeConfigurations[0].networkConfiguration.subnets | join(\",\")"); \
		aws ecs update-express-gateway-service \
			--service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/$(SVC) \
			--primary-container "$$PRIMARY_JSON" \
			--network-configuration "securityGroups=$$SGS,subnets=$$SUBS" \
			--monitor-resources DEPLOYMENT --region $(AWS_REGION); \
	else \
		echo "Creating new service $(SVC)..."; \
		aws ecs create-express-gateway-service \
			--service-name $(SVC) \
			--primary-container "$$PRIMARY_JSON" \
			--execution-role-arn arn:aws:iam::$(ACCOUNT_ID):role/ecsTaskExecutionRole \
			--infrastructure-role-arn arn:aws:iam::$(ACCOUNT_ID):role/ecsInfrastructureRoleForExpressServices \
			--monitor-resources; \
	fi

status:
	@for svc in $(RESEARCHER_SVC) $(JUDGE_SVC) $(CONTENT_BUILDER_SVC) $(ORCHESTRATOR_SVC) $(APP_SVC); do \
		echo "--- Status for $$svc ---"; \
		DESC=$$(aws ecs describe-express-gateway-service --service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/$$svc 2>/dev/null); \
		if [ -n "$$DESC" ]; then \
			echo "$$DESC" | python3 -c "import sys, json; data = json.load(sys.stdin); s = data['service']; \
				status = s['status']['statusCode']; \
				endpoint = s['activeConfigurations'][0]['ingressPaths'][0]['endpoint'] if s.get('activeConfigurations') else 'N/A'; \
				print(f\"Service: {s['serviceName']}\nStatus: {status}\nEndpoint: https://{endpoint}\")"; \
		else \
			echo "Service $$svc not found."; \
		fi; \
	done

endpoint:
	@REGION=$$( [ -z "$(AWS_REGION)" ] && echo "us-east-1" || echo "$(AWS_REGION)" ); \
	ACCOUNT=$$( [ -z "$(ACCOUNT_ID)" ] && aws sts get-caller-identity --query "Account" --output text 2>/dev/null || echo "$(ACCOUNT_ID)" ); \
	if [ -z "$$ACCOUNT" ]; then echo "Error: ACCOUNT_ID not set and could not be fetched."; exit 1; fi; \
	ENDPOINT=$$(aws ecs describe-express-gateway-service --service-arn arn:aws:ecs:$$REGION:$$ACCOUNT:service/default/$(APP_SVC) --query 'service.activeConfigurations[0].ingressPaths[0].endpoint' --output text --region $$REGION 2>/dev/null); \
	if [ -z "$$ENDPOINT" ] || [ "$$ENDPOINT" = "None" ]; then \
		echo "App Endpoint not found."; \
	else \
		echo "https://$$ENDPOINT"; \
	fi

aws-destroy:
	@for svc in $(RESEARCHER_SVC) $(JUDGE_SVC) $(CONTENT_BUILDER_SVC) $(ORCHESTRATOR_SVC) $(APP_SVC); do \
		echo "Destroying AWS resources for $$svc..."; \
		aws ecs delete-express-gateway-service --service-arn arn:aws:ecs:$(AWS_REGION):$(ACCOUNT_ID):service/default/$$svc 2>/dev/null || true; \
	done
	@echo "AWS resources destroyed."

# --- Original Local Development Targets ---

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
	@echo "  deploy-ecsexpress     - Deploy 5 separate services to ECS Express Mode"
	@echo "  destroy-ecsexpress    - Destroy all ECS Express services"
	@echo "  status-ecsexpress     - Show status for all 5 services"
	@echo "  endpoint-ecsexpress   - Show Web App endpoint"
	@echo "  e2e-test-ecsexpress   - Run E2E test against the distributed deployment"

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

local:
	@echo "--- Local Service URLs ---"
	@echo "Frontend: http://localhost:5173"
	@echo "Backend:  http://localhost:8000 (main app)"
	@echo "Agents:"
	@echo "  Researcher:      http://localhost:8001"
	@echo "  Judge:           http://localhost:8002"
	@echo "  Content Builder: http://localhost:8003"
	@echo "  Orchestrator:    http://localhost:8004"

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

e2e-test-ecsexpress:
	@echo "Fetching App endpoint..."
	@ENDPOINT=$$($(MAKE) -s endpoint); \
	if [ "$$ENDPOINT" = "App Endpoint not found." ] || [ -z "$$ENDPOINT" ]; then \
		echo "Error: Web App endpoint not found."; \
		exit 1; \
	fi; \
	echo "Testing against: $$ENDPOINT"; \
	$(MAKE) e2e-test TEST_URL=$$ENDPOINT

deploy-ecsexpress: deploy

destroy-ecsexpress: aws-destroy

status-ecsexpress: status

endpoint-ecsexpress: endpoint

stop-local:
	@echo "Stopping any existing agent and server processes..."
	@pkill -9 -f "[s]hared[.]adk_app" 2>/dev/null || true
	@pkill -9 -f "[m]ain[.]py" 2>/dev/null || true
	@pkill -9 -f "[v]ite" 2>/dev/null || true

clean:
	@echo "Cleaning up logs, caches, and temporary files..."
	find . -type f -name "*.log" -delete 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".adk" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".ruff_cache" -exec rm -rf {} + 2>/dev/null || true
	rm -rf app/dist 2>/dev/null || true
	@echo "Clean completed."
