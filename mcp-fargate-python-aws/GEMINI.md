# Gemini Code Assistant Context

This document provides context for the Gemini Code Assistant to understand the project and assist in development.

## Project Overview

This is a **Python-based Model Context Protocol (MCP) server** using the `FastMCP` class from the `mcp` SDK. It is designed to expose tools (like `greet`) over HTTP for integration with MCP clients (such as Claude Desktop or Gemini clients).

## Key Features

*   **MCP Tools:** Exposes the `greet` tool for parameter echoing.
*   **HTTP Health Check:** Provides a `/health` endpoint for AWS ECS health monitoring.
*   **AWS Fargate Optimized:** Pre-configured with a `Makefile` and Docker for seamless deployment to AWS Fargate.
*   **Structured Logging:** Uses `python-json-logger` for JSON-formatted logs to stderr.
*   **Automated Testing:** Pytest suite included for verifying tools and endpoints.

## Key Technologies

*   **Language:** Python 3.10+
*   **SDK:** `mcp` (Model Context Protocol SDK)
*   **Library:** `FastMCP` (for simplified server creation)
*   **Logging:** `python-json-logger`
*   **Dependency Management:** `pip` / `requirements.txt`
*   **Infrastructure:** AWS ECS (Fargate), ECR, CloudWatch Logs

## Project Structure

*   `main.py`: The entry point. Initializes the `FastMCP` server ("hello-world-server"), defines the `greet` tool, and a custom `/health` route.
*   `tests/`: Unit tests using Pytest.
*   `requirements.txt`: Python dependencies.
*   `Makefile`: Development and deployment automation.
*   `Dockerfile`: Containerization setup for deployment.
*   `task-definition.json.template`: ECS task definition template.
*   `save-aws-creds.sh`: Script for updating `.aws_creds` file for Makefile authentication.

## Development Setup

1.  **Create and activate a virtual environment (optional but recommended):**
    ```bash
    python3 -m venv .venv
    source .venv/bin/activate
    ```

2.  **Update Credentials (if needed):**
    If you use temporary session tokens, run:
    ```bash
    ./save-aws-creds.sh
    ```

3.  **Install Dependencies:**
    ```bash
    make install
    ```

## Running the Server

The server is configured to run using the `HTTP` transport on `http://localhost:8080`.

```bash
make run
```

## Makefile Commands

The `Makefile` is the primary interface for development and deployment tasks:

- **Monitoring:**
    - `make status`: Queries AWS for the current ECS service state.
    - `make git-status`: Shows git status.
    - `make endpoint`: Fetches the public IP of the running Fargate task.
    - `make logs`: Tails CloudWatch logs for the service.
- **Deployment:**
    - `make deploy` (or `make fargate`): Full cycle: create log group, create cluster, build image, ecr-login, push-ecr, register-task, and update/create service.
    - `make docker-build`: Build the container image locally.
    - `make ecr-login`: Authenticate Docker with Amazon ECR.
    - `make push-ecr`: Push image to ECR (auto-creates repo if needed).
    - `make register-task`: Register a new ECS task definition from template.
    - `make create-cluster`: Ensures the ECS cluster exists.
    - `make update-or-create-service`: Manages the ECS service lifecycle.
- **Cleanup:**
    - `make delete-service`: Stops and deletes the ECS service.
    - `make delete-cluster`: Deletes the ECS cluster.
- **Code Quality:**
    - `make test`: Run pytest suite.
    - `make lint`: Run flake8.
    - `make format`: Run black.
    - `make type-check`: Run mypy.
- **Utilities:**
    - `make clean`: Removes temporary files, virtual environments, and build artifacts.
    - `make pull` / `make push`: Git synchronization.

## Deployment Environment

The project is configured for deployment to **Amazon ECS with AWS Fargate**.

### Prerequisites
- AWS CLI installed and configured.
- Docker installed and running.
- IAM Role (`ecsTaskExecutionRole`) with permissions to pull from ECR and log to CloudWatch.

### Fargate Service Setup

The `Makefile` handles most of the networking setup by using your account's **Default VPC**, subnets, and default security group.

To deploy for the first time:

```bash
make deploy
```

If you need to customize the networking (e.g., use a specific VPC or private subnets), you can override the variables in the `Makefile` or pass them as arguments.
