# Gemini Code Assistant Context

This document provides context for the Gemini Code Assistant to understand the project and assist in development.

## Project Overview

This project implements a complete **Model Context Protocol (MCP) ecosystem** on **Amazon Bedrock AgentCore**. It consists of two primary components:

1.  **Tool Provider (`app/hello_world_server`):** A Python-based MCP server using the `FastMCP` class. It is designed to be deployed as a managed tool runtime.
2.  **Tool Consumer (`app/testagent`):** A sophisticated agent built using the **Strands** framework that consumes tools from the MCP gateway.

Both are optimized for deployment to **Amazon Bedrock AgentCore** as managed runtimes.

**Mandatory Rule:** never setup a venv environment. The project uses global/container environments as managed by AgentCore.

### Reference Docs
- [From Local MCP to AWS Deployment](https://dev.to/aws/from-local-mcp-server-to-aws-deployment-in-two-commands-ag4)
- [AgentCore Console (US-East-1)](https://106059658660-inzdo536.us-east-1.console.aws.amazon.com/bedrock-agentcore/home?region=us-east-1#)
- [Uniting MCP Servers through AgentCore Gateway](https://aws.amazon.com/blogs/machine-learning/transform-your-mcp-architecture-unite-mcp-servers-through-agentcore-gateway/)

## Key Features

*   **MCP Tools:** Exposes the `greet` tool for parameter echoing via `FastMCP`.
*   **Strands Agent:** Uses the `strands` framework for agent orchestration, featuring dynamic tool discovery.
*   **AgentCore Optimized:** Pre-configured with AgentCore project structure (`agentcore/`) and CDK for deployment.
*   **Stateless HTTP:** Optimized for serverless runtimes using `stateless_http=True` and `streamable-http` transport.
*   **Structured Logging:** Uses `python-json-logger` for JSON-formatted logs.

## Key Technologies

*   **Language:** Python 3.12+
*   **Platform:** Amazon Bedrock AgentCore
*   **Frameworks:** `mcp` (FastMCP), `strands`
*   **Infrastructure:** AWS CDK (via AgentCore CLI)

## Project Structure

*   `agentcore/`: AgentCore project configuration (`agentcore.json`) and CDK infrastructure.
*   `app/hello_world_server/`: Tool provider code.
    *   `main.py`: FastMCP server definition.
*   `app/testagent/`: Tool consumer agent code.
    *   `main.py`: Strands agent entry point.
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

- **Deployment:** `make agentcore-deploy` (or `make deploy`)
- **Development:** `make agentcore-dev` (hot-reload for both components)
- **Monitoring:** `make agentcore-status`, `make agentcore-logs`
- **Code Quality:** `make test`, `make lint`, `make format`, `make type-check`
