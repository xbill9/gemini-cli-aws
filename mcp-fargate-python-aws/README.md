# MCP HTTP Python Server for AWS Fargate

A Model Context Protocol (MCP) server implemented in Python using `FastMCP`, configured for deployment on **Amazon ECS with AWS Fargate**. This server communicates over `HTTP`.

## Overview

This project provides an MCP server named `hello-world-server` that exposes a `greet` tool. It uses `python-json-logger` for structured logging to stderr, ensuring that stdout remains reserved for JSON-RPC messages. It is specifically pre-configured with a `Makefile` and Docker setup for rapid deployment to AWS Fargate.

## Prerequisites

- **Python 3.10+**
- **AWS CLI** configured with appropriate permissions.
- **Docker** installed and running.
- **Amazon ECR Repository** and **ECS Cluster** created (managed via `make deploy`).

## Installation

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd mcp-fargate-python-aws
    ```

2.  **Set up credentials:**
    If you use temporary credentials (e.g., from AWS SSO or a lab environment), run the helper script to export them for the Makefile:
    ```bash
    ./save-aws-creds.sh
    ```
    This script saves active credentials to a `.aws_creds` file which the `Makefile` automatically includes.

3.  **Install dependencies:**
    ```bash
    make install
    ```

## Usage

### Local Running
To run the server manually:
```bash
make run
# or
python main.py
```
The server starts on `http://localhost:8080` by default.

### Deployment to AWS Fargate
The `Makefile` handles the full deployment lifecycle, including infrastructure setup:
```bash
make deploy
```
This will:
1.  **Ensure a CloudWatch Log Group** exists for the container logs (`/ecs/mcp-fargate-task`).
2.  **Ensure an ECS Cluster** exists (`mcp-fargate-cluster`).
3.  **Build the Docker image** locally.
4.  **Login to Amazon ECR**.
5.  **Push the image** to your ECR repository (auto-creating it if necessary).
6.  **Register a new task definition** with the latest image.
7.  **Update or create the ECS service** with auto-detected network settings (using your default VPC, subnets, and security group).

## Monitoring Status
You can check the remote ECS service status:
```bash
make status
```
Or specifically for git:
```bash
make git-status
```
To tail live logs from Fargate:
```bash
make logs
```
To find the public IP of your running task:
```bash
make endpoint
```

## Cleanup
To remove the deployed resources:
```bash
make delete-service
make delete-cluster
```

## Tools and Endpoints

### `greet` (MCP Tool)
- **Description:** Get a greeting from the MCP server.
- **Parameters:**
    - `param` (string): The text or name to echo back.
- **Returns:** The string passed in `param`.

### `/health` (Custom Route)
- **Description:** A standard HTTP GET endpoint for health checks.
- **Returns:** `{"status": "healthy", "service": "mcp-server"}`.
- **Usage:** Used by AWS ECS health checks to monitor container health.

## Development Tasks

- **`make status`**: Show ECS service status.
- **`make git-status`**: Show git status.
- **`make test`**: Run pytest suite.
- **`make lint`**: Check code style (flake8).
- **`make format`**: Auto-format code (black).
- **`make type-check`**: Run static type analysis (mypy).
- **`make clean`**: Remove build artifacts and virtual environments.

## Project Structure

- `main.py`: FastMCP server definition, custom `/health` route, and `greet` tool.
- `Makefile`: Centralized automation for dev, test, and AWS deployment.
- `Dockerfile`: Container definition for Fargate.
- `task-definition.json.template`: Template for ECS task definitions.
- `save-aws-creds.sh`: Helper for managing AWS session credentials.
- `tests/`: Pytest test suite for main server functionality.
