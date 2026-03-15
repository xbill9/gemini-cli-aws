# Gemini Code Assistant Context

This document provides context for the Gemini Code Assistant to understand the project and assist in development.

## Project Overview

This is a **Python-based Model Context Protocol (MCP) server** using the `FastMCP` class from the `mcp` SDK. It is designed to expose tools (like `greet`) over HTTP/SSE for integration with MCP clients (such as Claude Desktop or Gemini clients).

## Key Technologies

*   **Language:** Python 3
*   **SDK:** `mcp` (Model Context Protocol SDK)
*   **Library:** `FastMCP` (for simplified server creation)
*   **Adapter:** `Mangum` (for AWS Lambda ASGI support)
*   **Transport:** **Stateless HTTP** (Required for AWS Lambda to avoid "Session not found" errors)
*   **Logging:** `python-json-logger`
*   **Dependency Management:** `pip` / `requirements.txt`
*   **Deployment:** AWS Lambda (Container Image)

### Why Stateless HTTP?
AWS Lambda functions are stateless and can have multiple concurrent instances. Standard MCP SSE transport requires session affinity (the client must hit the same Lambda instance for SSE and subsequent POST messages). Since Lambda Function URLs do not support session affinity, we use FastMCP's `stateless_http=True` mode, which handles each request independently and avoids "Session not found" errors.

AWS Lambda:
https://aws.amazon.com/lambda/

## Project Structure

*   `main.py`: The entry point of the application. Initializes the `FastMCP` server ("hello-world-server"), defines tools, and exports a Mangum `handler` for AWS Lambda.
*   `requirements.txt`: Python dependencies.
*   `Makefile`: Development and deployment automation.
*   `save-aws-creds.sh`: Script for updating `.aws_creds` file used by the Makefile.
*   `Dockerfile`: Container definition for AWS Lambda.

## Development Setup

1.  **Create and activate a virtual environment (optional but recommended):**
    ```bash
    python3 -m venv .venv
    source .venv/bin/activate
    ```

2.  **Update Credentials (if needed):**
    ```bash
    ./save-aws-creds.sh
    ```

3.  **Install Dependencies:**
    ```bash
    make install
    ```

## Running the Server

The server can be run locally using the `HTTP` transport on `http://localhost:8080`.

```bash
make run
```

## Makefile Commands

The `Makefile` is the primary interface for development and deployment tasks:

- **Monitoring:**
    - `make status`: Shows both git status and AWS Lambda function status.
    - `make git-status`: Shows only git status.
    - `make lambda-status`: Queries AWS for the current Lambda function state.
    - `make endpoint`: Gets the public Lambda Function URL.
- **Deployment:**
    - `make deploy`: Full cycle: IAM setup, build, push to ECR, and create/update Lambda function.
    - `make docker-build`: Build the container image locally (using Lambda base image).
    - `make push-ecr`: Tag and push the container image to Amazon ECR.
    - `make iam-setup`: Ensures the `McpLambdaExecutionRole` exists for Lambda execution.
- **Code Quality:**
    - `make lint`: Run flake8 (if configured).
    - `make format`: Run black (if configured).

## Deployment Environment

The project is configured for deployment to **AWS Lambda** using a container image and **Lambda Function URLs** for public access.

### Prerequisites
- AWS CLI installed and configured.
- Docker installed and running.

### IAM Permissions
Deployment requires permissions to:
1. Create/Update IAM Roles (for `McpLambdaExecutionRole`).
2. Create/Describe/Push to Amazon ECR.
3. Create/Update/Invoke Amazon Lambda functions.
