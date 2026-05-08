# Gemini Code Assistant Context

This document provides context for the Gemini Code Assistant to understand the project and assist in development.

## Project Overview

This project implements a consolidated **Agent Development Kit (ADK) Studio** on **Amazon Bedrock AgentCore**. It exposes all agents in the `app/` directory via a single, native ADK Web interface.

**Mandatory Rule:** never setup a venv environment. The project uses global/container environments as managed by AgentCore.

### Reference Docs
- [ADK Documentation](https://adk.dev/)
- [AgentCore Console (US-East-1)](https://106059658660-inzdo536.us-east-1.console.aws.amazon.com/bedrock-agentcore/home?region=us-east-1#)

## Key Features

*   **Unified ADK Studio:** Serves multiple agents (`Agent1`, `Agent2`, `Agent3`, `Agent4`) from a single runtime endpoint.
*   **Direct Connect:** Accessible via standard HTTP/HTTPS, providing the native ADK Web UI (playground).
*   **AgentCore Native:** Deployed as a standard `HTTP` runtime on Amazon Bedrock AgentCore.
*   **Zero MCP:** The Model Context Protocol (MCP) layer has been completely removed in favor of direct ADK integration.

## Key Technologies

*   **Language:** Python 3.12+
*   **Platform:** Amazon Bedrock AgentCore
*   **Frameworks:** `google-adk`, `FastAPI`, `uvicorn`
*   **Infrastructure:** AWS CDK (via AgentCore CLI)

## Project Structure

*   `agentcore/`: AgentCore project configuration (`agentcore.json`) and CDK infrastructure.
*   `app/`: The root directory for all ADK agents.
    *   `fast_api_app.py`: Consolidated entrypoint serving all agents.
    *   `Agent1/` to `Agent4/`: Individual agent definitions.
*   `Makefile`: Development and deployment automation.

## Development Setup

1.  **Install AgentCore CLI:**
    ```bash
    npm install -g @aws/agentcore
    ```

2.  **Install Dependencies:**
    ```bash
    make install
    ```

## Makefile Commands

- **Deployment:** `make deploy` (or `make agentcore-deploy`)
- **Development:** `make run` (local ADK Studio), `make agentcore-dev` (AgentCore local dev)
- **Monitoring:** `make agentcore-status`, `make endpoint`
- **Code Quality:** `make lint`, `make format`, `make type-check`
