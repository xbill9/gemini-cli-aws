# Gemini Code Assistant Context

This document provides context for the Gemini Code Assistant to understand the project and assist in development.

## Project Overview

This is a **Python-based Model Context Protocol (MCP) server** using the `FastMCP` class from the `mcp` SDK. It is designed to expose tools (like `greet`) over HTTP/SSE for integration with MCP clients (such as Claude Desktop or Gemini clients).

## Key Technologies

*   **Language:** Python 3.13
*   **SDK:** `mcp` (Model Context Protocol SDK)
*   **Library:** `FastMCP` (for simplified server creation)
*   **Adapter:** [AWS Lambda Web Adapter](https://github.com/awslabs/aws-lambda-web-adapter) (v1.0.0+)
*   **Transport:** **Stateless HTTP**
*   **Compute:** **AWS Lambda Managed Instances** (Dedicated EC2 capacity)
*   **Networking:** **VPC with NAT Gateway** (for outbound internet access)
*   **Logging:** Python `logging` to stderr (structured/JSON friendly)
*   **Dependency Management:** `pip` / `requirements.txt`
*   **Deployment:** Hybrid (CloudFormation for VPC/IAM/API Gateway + AWS CLI for Capacity Provider & Lambda)

### Why Managed Instances?
Managed Instances provide dedicated EC2 capacity for Lambda functions. This allows for **multi-concurrency** (one execution environment handles multiple requests simultaneously) and eliminates cold starts.

### Important Learnings
*   **AWS Lambda Web Adapter v1.0.0+** is required for Managed Instances support.
*   The function's primary state may show as **`ActiveNonInvocable`**. This is expected for Managed Instances functions that haven't been invoked yet or are in a warm-up state.
*   You must **publish a version** (or use `$LATEST.PUBLISHED`) to invoke the function.
*   Managed Instances require at least **2GB Memory** and **1 vCPU** (enforced in `deploy.sh`).
*   **Multi-concurrency** is automatically enabled (default 8 per instance).
*   **Response Streaming:** The Web Adapter is configured in `response` mode (`AWS_LAMBDA_WEB_ADAPTER_INVOKE_MODE=response`) to support MCP SSE.

### Networking (VPC)
Managed Instances run within a VPC. The deployment includes:
- **Public Subnet:** Hosts the NAT Gateway.
- **Private Subnet:** Hosts the Lambda function.
- **NAT Gateway:** Provides the Lambda function with outbound internet access.
- **Internet Gateway:** Connects the VPC to the internet.

## Project Structure

*   `main.py`: The entry point. Initializes FastMCP and Starlette app.
*   `template.yaml`: CloudFormation template for the VPC, NAT Gateway, IAM roles, and API Gateway.
*   `deploy.sh`: Script to manage the hybrid deployment (CFN + CLI for Capacity Provider & Lambda).
*   `destroy.sh`: Clean teardown script.
*   `requirements.txt`: Python dependencies.
*   `Makefile`: Automation entry point.
*   `Dockerfile`: Container definition based on `python:3.13-slim` with AWS Lambda Web Adapter.

## Deployment Setup

1.  **Update Credentials:**
    ```bash
    ./save-aws-creds.sh
    ```

2.  **Deploy:**
    ```bash
    make deploy
    # or
    ./deploy.sh
    ```
    *Note: The first deployment takes ~5-10 minutes due to NAT Gateway creation.*

## Makefile Commands

- **Monitoring:**
    - `make status`: Queries AWS for the current Lambda and Alias state.
    - `make endpoint`: Gets the public API Gateway endpoint.
- **Deployment:**
    - `make deploy`: Full deployment cycle (Tests -> ECR -> CFN -> CP -> Lambda).
    - `make docker-build`: Build the container image locally.
- **Teardown:**
    - `make aws-destroy`: Removes ALL resources (VPC, NAT, Lambda, Capacity Provider, ECR) to stop billing.
