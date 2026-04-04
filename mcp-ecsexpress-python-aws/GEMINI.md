# Gemini Code Assistant Context

This document provides context for the Gemini Code Assistant to understand the project and assist in development.

## Project Overview

This is a **Python-based Model Context Protocol (MCP) server** using the `FastMCP` class from the `mcp` SDK. It is designed to expose tools (like `greet`) over HTTP for integration with MCP clients (such as Claude Desktop or Gemini clients).

## Key Technologies

*   **Language:** Python 3
*   **SDK:** `mcp` (Model Context Protocol SDK)
*   **Library:** `FastMCP` (for simplified server creation)
*   **Logging:** `python-json-logger`
*   **Dependency Management:** `pip` / `requirements.txt`

## Project Structure

*   `main.py`: The entry point of the application. Initializes the `FastMCP` server ("hello-world-server") and defines tools.
*   `requirements.txt`: Python dependencies.
*   `Makefile`: Development and deployment automation.
*   `save-aws-creds.sh`: Script for updating `.aws_creds` file used by the Makefile.

## Development Setup


2.  **Update Credentials (if needed):**
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
make release
```

### Health Check Endpoints
The server exposes two health check endpoints for infrastructure monitoring:
- `GET /`
- `GET /health`

## Makefile Commands

The `Makefile` is the primary interface for development and deployment tasks:

- **Monitoring & Management:**
    - `make status`: Shows ECS Express Mode service status and endpoint.
    - `make endpoint`: Retrieves the public endpoint URL for the ECS service.
    - `make aws-destroy`: Deletes the ECS Express Mode service.
    - `make git-status`: Shows only git status.
    - `make ecs-status`: Queries AWS for the current ECS Express Mode service state.
- **Deployment:**
    - `make deploy`: Full cycle: build image, push to ECR, and deploy to ECS Express Mode.
    - `make cloudrun`: Submits a build to Google Cloud Build using `cloudbuild.yaml`.
    - `make docker-build`: Build the local container image.
    - `make ecr-push`: Setup ECR, login, and push the image.
    - `make ecs-deploy`: Create or update the ECS Express Mode service.
    - `make iam-roles`: Create the required IAM roles for ECS Express Mode.
- **Code Quality:**
    - `make test`: Run pytest suite.
    - `make lint`: Run flake8.
    - `make format`: Run black.
    - `make type-check`: Run mypy.

## Deployment Environment

The project is configured for deployment to **AWS ECS Express Mode**.

### Prerequisites
- AWS CLI (v2.33.15 or later) installed and configured.
- Docker installed and running.
- IAM permissions to create roles, ECR repositories, and ECS services.

### ECS Express Mode

ECS Express Mode is a simplified deployment path that automates the creation of Application Load Balancers, Target Groups, Security Groups, and Auto Scaling with a single command. It uses the `aws ecs create-express-gateway-service` command.

## Python MCP Developer Resources
