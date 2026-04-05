# MCP HTTP Python Server for Amazon EKS

A Model Context Protocol (MCP) server implemented in Python using `FastMCP`, configured for deployment on **Amazon EKS (Kubernetes)**. This server communicates over `HTTP`.

## Overview

This project provides an MCP server named `hello-world-server` that exposes a `greet` tool. It uses `python-json-logger` for structured logging to stderr, ensuring that stdout remains reserved for JSON-RPC messages. It is specifically pre-configured with a `Makefile`, Kubernetes manifests, and Docker setup for rapid deployment to Amazon EKS.

## Prerequisites

- **Python 3.10+**
- **AWS CLI** configured with appropriate permissions.
- **Docker** installed and running.
- **kubectl** installed for Kubernetes management.
- **Amazon ECR Repository** and an existing **EKS Cluster** (or use `make cluster-create` to create one).

## Installation

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd mcp-eks-python-aws
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

## EKS Cluster Management

If you don't have an EKS cluster yet, you can create one using `eksctl` via the Makefile:

```bash
# Create the cluster (takes ~15-20 minutes)
make cluster-create
```

This uses `eks-cluster.yaml` to provision a cluster named `mcp-eks-cluster` in `us-east-1` with a managed node group.

To delete the cluster later:
```bash
make cluster-delete
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

### Deployment to Amazon EKS
To deploy to an EKS cluster:
```bash
make deploy EKS_CLUSTER=<your-cluster-name>
```
If you created the cluster using `make cluster-create`, the default name is `mcp-eks-cluster`.

This will:
1.  **Update your kubeconfig** for the specified cluster.
2.  **Build the Docker image** locally.
3.  **Login to Amazon ECR**.
4.  **Push the image** to your ECR repository (auto-creating it if necessary).
5.  **Generate a Kubernetes manifest** (`k8s-deployment.yaml`) from the template.
6.  **Apply the manifest** using `kubectl`.

## Monitoring Status
You can check the EKS deployment status:
```bash
make status
```
To tail live logs:
```bash
make logs
```
To find the public LoadBalancer endpoint:
```bash
make endpoint
```

## Cleanup
To remove the deployed resources:
```bash
make aws-destroy
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
- **Usage:** Used by Kubernetes liveness and readiness probes to monitor container health.

## Development Tasks

- **`make help`**: Show all available Makefile commands.
- **`make status`**: Show EKS deployment status.
- **`make test`**: Run pytest suite.
- **`make lint`**: Check code style (flake8).
- **`make format`**: Auto-format code (black).
- **`make type-check`**: Run static type analysis (mypy).
- **`make clean`**: Remove build artifacts and virtual environments.
- **`make git-status`**: Show git status.
- **`make endpoint`**: Fetch the public LoadBalancer hostname.
- **`make logs`**: Tail logs for EKS pods.

## Project Structure

- `main.py`: FastMCP server definition, custom `/health` route, and `greet` tool.
- `Makefile`: Centralized automation for dev, test, and EKS deployment.
- `Dockerfile`: Container definition for the server.
- `k8s-deployment.yaml.template`: Template for Kubernetes deployment and service.
- `save-aws-creds.sh`: Helper for managing AWS session credentials.
- `tests/`: Pytest test suite for main server functionality.
