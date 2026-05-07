# AgentCore MCP Python System

A comprehensive Model Context Protocol (MCP) system designed for **Amazon Bedrock AgentCore**, featuring both a tool-providing server and a tool-consuming agent.

## Overview

This project demonstrates a complete AgentCore ecosystem:
1.  **Tool Provider (`hello-world-server`):** A Python MCP server using `FastMCP` that exposes managed tools.
2.  **Tool Consumer (`test-agent`):** A sophisticated agent built with the `strands` framework that consumes tools from the MCP gateway.

Both components are optimized for serverless execution using AgentCore Runtime and communicate via the MCP standard.

## Prerequisites

- **Python 3.12+**
- **Node.js 25+** (for AgentCore CLI and CDK)
- **AgentCore CLI** installed:
    ```bash
    npm install -g @aws/agentcore
    ```
- **AWS CLI** configured with appropriate permissions.

## Project Structure

- `agentcore/`: AgentCore project configuration (`agentcore.json`) and CDK infrastructure.
- `app/`:
    - `hello_world_server/`: The core MCP server (Tool Provider).
    - `testagent/`: An agent that consumes the MCP tools (Tool Consumer).
- `Makefile`: Centralized automation for development, testing, and AgentCore operations.

## Installation

1.  **Clone the repository.**
2.  **Authenticate with AWS:**
    Ensure your AWS CLI is configured. To enable the Makefile to use your current session:
    ```bash
    ./save-aws-creds.sh
    ```
3.  **Install dependencies:**
    ```bash
    make install
    ```

## Local Development

### Running the MCP Server Directly
To run the MCP server locally:
```bash
make run
```

### Development with Hot-Reload
To use the AgentCore CLI's development mode (supports hot-reloading for both components):
```bash
make agentcore-dev
```

## Deployment

The system is deployed to AWS via the AgentCore Runtime using CDK:

```bash
make deploy
```
*(This is a shortcut for `make agentcore-deploy`)*

## Monitoring and Maintenance

- **Status:** Check deployment status:
    ```bash
    make status
    ```
- **Endpoints:** Retrieve the deployed gateway URL:
    ```bash
    make endpoint
    ```
- **Logs:** Stream logs from the deployed runtime:
    ```bash
    make agentcore-logs
    ```
- **Tests:** Run the pytest suite:
    ```bash
    make test
    ```
- **Code Quality:** Run linting, formatting, and type checking:
    ```bash
    make lint
    make format
    make type-check
    ```

## Tools and Endpoints

### MCP Tools (Provided by `hello_world_server`)
- **`greet`**: Get a greeting from the MCP server.
    - **Parameters:** `param` (string).
- **`/health`**: Custom HTTP route for service health checks.

### Agent (Provided by `testagent`)
- **Framework:** Strands
- **Capability:** Dynamically discovers and invokes tools from the AgentCore Gateway.
- **Local Tools:**
    - **`add_numbers`**: A sample local tool that adds two integers.
- **Runtime:** Managed by `BedrockAgentCoreApp`.

## Cleanup
To remove local build artifacts:
```bash
make clean
```
