# MCP HTTP Python Server for AWS Lambda (Managed Instances)

A Model Context Protocol (MCP) server implemented in Python using `FastMCP`, configured for high-performance deployment on **AWS Lambda Managed Instances**. This server communicates over `Stateless HTTP` and is optimized for multi-concurrency and zero cold starts.

## Overview

This project provides an MCP server named `mcp-lambda-python-aws` that exposes a `greet` tool. It uses the **AWS Lambda Web Adapter** to provide ASGI support for AWS Lambda and `FastMCP`'s `stateless_http=True` mode to handle MCP SSE transport correctly.

### Architecture Highlights

- **Compute:** [AWS Lambda Managed Instances](https://docs.aws.amazon.com/lambda/latest/dg/lambda-managed-instances.html) providing dedicated EC2 capacity.
- **Networking:** Deployed within a **VPC** with a **NAT Gateway** to allow the Lambda function to access the internet (required for many MCP tools).
- **Transport:** SSE over HTTP (Stateless).
- **Infrastrucure as Code:** Hybrid approach using CloudFormation (`template.yaml`) for networking/IAM and the AWS CLI (`deploy.sh`) for Managed Instances specific resources.
- **Containerized:** Based on `python:3.13-slim`.

## Prerequisites

- **Python 3.10+**
- **AWS CLI** configured with appropriate permissions.
- **Docker** installed and running.

## Installation

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd mcp-lambda-python-aws
    ```

2.  **Set up credentials:**
    If you use temporary credentials (e.g., from AWS SSO or a lab environment), run the helper script to export them for the Makefile:
    ```bash
    ./save-aws-creds.sh
    ```

3.  **Install dependencies:**
    ```bash
    make install
    ```

## Usage

### Local Running
To run the server manually for local testing:
```bash
make run
# or
python main.py
```
The server starts on `http://localhost:8080` by default.

### Deployment to AWS
The project uses a unified deployment script:
```bash
make deploy
```
This script performs the following actions:
1.  Runs local tests (`pytest`).
2.  Builds the Docker image and pushes it to Amazon ECR.
3.  Deploys the VPC, NAT Gateway, IAM roles, and API Gateway via CloudFormation.
4.  Creates/Updates the Lambda Capacity Provider.
5.  Deploys the Lambda function as a Managed Instance.
6.  Publishes a new version and updates the `prod` alias.

*Note: The first deployment takes ~5-10 minutes due to VPC/NAT Gateway provisioning.*

## Monitoring & Status
Check the status of your deployment:
```bash
make status
```
To get the public API Gateway endpoint:
```bash
make endpoint
```

## MCP Configuration
To use this server with an MCP client (like Claude Desktop), use the following configuration, replacing `<URL>` with the output of `make endpoint`:

```json
{
  "mcpServers": {
    "lambda-aws": {
      "command": "curl",
      "args": ["-N", "<URL>/mcp/"]
    }
  }
}
```
*Note: Ensure you include the `/mcp/` path.*

## Tools

### `greet`
- **Description:** Get a greeting from the local server.
- **Parameters:**
    - `param` (string): The text or name to echo back.
- **Returns:** A friendly greeting string.

## Development Commands

- **`make test`**: Run the test suite.
- **`make status`**: Show AWS Lambda function and alias status.
- **`make endpoint`**: Display the public API Gateway URL.
- **`make lint`**: Check code style (flake8).
- **`make format`**: Auto-format code (black).
- **`make aws-destroy`**: Tear down ALL AWS resources to stop billing.

## Project Structure

- `main.py`: FastMCP server definition with Starlette/ASGI integration.
- `template.yaml`: CloudFormation template for VPC, NAT, IAM, and API Gateway.
- `deploy.sh`: Orchestration script for the full AWS deployment.
- `destroy.sh`: Cleanup script for AWS resources.
- `Makefile`: Centralized automation for development and deployment.
- `Dockerfile`: Container definition with AWS Lambda Web Adapter.
