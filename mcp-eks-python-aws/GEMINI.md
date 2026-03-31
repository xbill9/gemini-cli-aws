# Gemini Code Assistant Context

This document provides context for the Gemini Code Assistant to understand the project and assist in development.

## Project Overview

This is a **Python-based Model Context Protocol (MCP) server** using the `FastMCP` class from the `mcp` SDK. It is designed to expose tools (like `greet`) over HTTP for integration with MCP clients (such as Claude Desktop or Gemini clients).

## Key Features

*   **MCP Tools:** Exposes the `greet` tool for parameter echoing.
*   **HTTP Health Check:** Provides a `/health` endpoint for Kubernetes health monitoring.
*   **EKS Optimized:** Pre-configured with a `Makefile`, Kubernetes manifests, and Docker for seamless deployment to Amazon EKS.
*   **Structured Logging:** Uses `python-json-logger` for JSON-formatted logs to stderr.
*   **Automated Testing:** Pytest suite included for verifying tools and endpoints.

## Key Technologies

*   **Language:** Python 3.10+
*   **SDK:** `mcp` (Model Context Protocol SDK)
*   **Library:** `FastMCP` (for simplified server creation)
*   **Logging:** `python-json-logger`
*   **Dependency Management:** `pip` / `requirements.txt`
*   **Infrastructure:** Amazon EKS, ECR, CloudWatch Logs

## Project Structure

*   `main.py`: The entry point. Initializes the `FastMCP` server ("hello-world-server"), defines the `greet` tool, and a custom `/health` route.
*   `tests/`: Unit tests using Pytest.
*   `requirements.txt`: Python dependencies.
*   `Makefile`: Development and deployment automation for EKS.
*   `Dockerfile`: Containerization setup for deployment.
*   `k8s-deployment.yaml.template`: Kubernetes manifest template.
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
    - `make status`: Queries EKS for the current deployment and service state.
    - `make git-status`: Shows git status.
    - `make endpoint`: Fetches the LoadBalancer hostname of the running EKS service.
    - `make logs`: Tails logs for the EKS pods.
- **Deployment:**
    - `make deploy` (or `make eks`): Full cycle: update kubeconfig, build image, ecr-login, push-ecr, and deploy to EKS.
    - `make docker-build`: Build the container image locally.
    - `make ecr-login`: Authenticate Docker with Amazon ECR.
    - `make push-ecr`: Push image to ECR (auto-creates repo if needed).
- **Cleanup:**
    - `make aws-destroy`: Deletes EKS resources and ECR repository.
- **Code Quality:**
    - `make test`: Run pytest suite.
    - `make lint`: Run flake8.
    - `make format`: Run black.
    - `make type-check`: Run mypy.
- **Utilities:**
    - `make clean`: Removes temporary files, virtual environments, and build artifacts.
    - `make pull` / `make push`: Git synchronization.

## Deployment Environment

The project is configured for deployment to **Amazon EKS (Kubernetes)**.

### Prerequisites
- AWS CLI installed and configured.
- Docker installed and running.
- `kubectl` installed for Kubernetes management.

### EKS Service Setup

To deploy to an existing EKS cluster:

```bash
make deploy EKS_CLUSTER=<your-cluster-name>
```

The EKS deployment uses a LoadBalancer service to expose the server on port 80.
