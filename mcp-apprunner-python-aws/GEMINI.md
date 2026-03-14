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
*   **Deployment:** AWS App Runner

AWS App Runner:
https://aws.amazon.com/apprunner/
https://docs.aws.amazon.com/apprunner/latest/dg/what-is-apprunner.html

## Project Structure

*   `main.py`: The entry point of the application. Initializes the `FastMCP` server ("hello-world-server") and defines tools.
*   `requirements.txt`: Python dependencies.
*   `Makefile`: Development and deployment automation.
*   `save-aws-creds.sh`: Script for updating `.aws_creds` file used by the Makefile.
*   `Dockerfile`: Container definition for App Runner.

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

The server is configured to run using the `HTTP` transport on `http://localhost:8080`.

```bash
make run
```

## Makefile Commands

The `Makefile` is the primary interface for development and deployment tasks:

- **Monitoring:**
    - `make status`: Shows both git status and AWS App Runner service status.
    - `make git-status`: Shows only git status.
    - `make apprunner-status`: Queries AWS for the current App Runner service state.
- **Deployment:**
    - `make deploy`: Full cycle: IAM setup, build, push to ECR, and create/update App Runner service.
    - `make docker-build`: Build the container image locally.
    - `make push-ecr`: Tag and push the container image to Amazon ECR.
    - `make iam-setup`: Ensures the `AppRunnerECRAccessRole` exists for pulling from ECR.
- **Code Quality:**
    - `make lint`: Run flake8 (if configured).
    - `make format`: Run black (if configured).

## Deployment Environment

The project is configured for deployment to **AWS App Runner**.

### Prerequisites
- AWS CLI installed and configured.
- Docker installed and running.

### IAM Permissions
Deployment requires permissions to:
1. Create/Update IAM Roles (for `AppRunnerECRAccessRole`).
2. Create/Describe/Push to Amazon ECR.
3. Create/Update Amazon App Runner services.
