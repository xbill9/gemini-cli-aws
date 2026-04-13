# Makefile for Content Builder Agent

SHELL := /bin/bash
PYTHON = python3
PIP = pip3
PORT = 8003
AGENT_NAME = content_builder

# Find the project root directory
PROJECT_ROOT := $(shell git rev-parse --show-toplevel 2>/dev/null || pwd)
export PROJECT_ROOT

# Load .env file if it exists
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Support both GOOGLE_API_KEY and GEMINI_API_KEY
GOOGLE_API_KEY ?= $(GEMINI_API_KEY)
export GOOGLE_API_KEY

TOPIC ?= Please generate a course module based on these findings.
RESEARCH_FINDINGS ?= The Gemini 2.5 models are the latest from Google. They offer improved reasoning and speed. Key features include large context windows and native multimodal capabilities.

.PHONY: help install run start stop lint format test clean deploy-ecs a2a status test-invoke test-local

help:
	@echo "Available targets:"
	@echo "  install      - Install dependencies"
	@echo "  run          - Run the agent locally on port $(PORT)"
	@echo "  start        - Start the agent in background"
	@echo "  stop         - Stop the local agent"
	@echo "  status       - Check local service status"
	@echo "  lint         - Run linting (ruff)"
	@echo "  format       - Run formatting (ruff format)"
	@echo "  test         - Run tests (pytest)"
	@echo "  clean        - Remove temporary files and cache"
	@echo "  deploy-ecs   - Deploy to AWS ECS"
	@echo "  test-invoke  - Test the agent endpoint"
	@echo "  test-local   - Test the local agent endpoint"

status:
	@echo "--- Local Status (Port $(PORT)) ---"
	@if lsof -Pi :$(PORT) -sTCP:LISTEN -t >/dev/null; then \
		echo "Agent is RUNNING on port $(PORT)"; \
	else \
		echo "Agent is NOT RUNNING locally"; \
	fi

install:
	$(PIP) install -e .

run:
	$(PYTHON) -m shared.adk_app --port $(PORT) --a2a

start:
	@if lsof -Pi :$(PORT) -sTCP:LISTEN -t >/dev/null; then \
		echo "Agent is already running on port $(PORT)"; \
	else \
		echo "Starting agent on port $(PORT)..."; \
		nohup $(PYTHON) -m shared.adk_app --port $(PORT) --a2a > agent.log 2>&1 & echo $$! > agent.pid; \
		echo "Agent started with PID $$(cat agent.pid). Logging to agent.log"; \
	fi

stop:
	@echo "Stopping agent on port $(PORT)..."
	@if [ -f agent.pid ]; then \
		kill $$(cat agent.pid) && rm agent.pid; \
		echo "Agent stopped."; \
	elif lsof -Pi :$(PORT) -sTCP:LISTEN -t >/dev/null; then \
		lsof -Pi :$(PORT) -sTCP:LISTEN -t | xargs kill; \
		echo "Agent stopped."; \
	else \
		echo "Agent is not running."; \
	fi

lint:
	ruff check .

format:
	ruff format .
	ruff check . --fix

test:
	$(PYTHON) -m pytest

clean:
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.log" -exec rm -rf {} +
	rm -rf .adk/artifacts
	rm -rf .pytest_cache
	rm -rf .ruff_cache

deploy-ecs:
	@echo "Deploying to AWS ECS..."
	# Add ECS deployment logic here

test-invoke: test-local

test-local:
	@echo "Testing local endpoint at http://localhost:$(PORT)/a2a/$(AGENT_NAME) with topic: '$(TOPIC)'..."; \
	curl -s -X POST http://localhost:$(PORT)/a2a/$(AGENT_NAME) \
	  -H "Content-Type: application/json" \
	  -d '{"jsonrpc": "2.0", "id": "1", "method": "message/send", "params": {"contextId": "test-session", "message": {"role": "user", "parts": [{"text": "$(TOPIC)"}], "messageId": "m1"}}}' | jq .
