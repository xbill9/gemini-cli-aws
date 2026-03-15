# MCP HTTP Python Server for AWS Lambda

A Model Context Protocol (MCP) server implemented in Python using `FastMCP`, configured for deployment on **AWS Lambda** as a container image with **Lambda Function URLs**. This server communicates over `Stateless HTTP`.

## Overview

This project provides an MCP server named `mcp-lambda-python-aws` that exposes a `greet` tool. It uses `python-json-logger` for structured logging to stderr, ensuring that stdout remains reserved for JSON-RPC messages. It is specifically pre-configured with a `Makefile` and Docker setup for rapid deployment to AWS Lambda via Amazon ECR.

The server uses `Mangum` to provide ASGI support for AWS Lambda and `FastMCP`'s `stateless_http=True` mode to handle MCP SSE transport correctly without requiring session affinity.

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
To run the server manually:
```bash
make run
# or
python main.py
```
The server starts on `http://localhost:8080` by default.

### Deployment to AWS Lambda
The `Makefile` handles the full deployment lifecycle:
```bash
make deploy
```
This will:
1. Ensure the necessary IAM role (`McpLambdaExecutionRole`) exists.
2. Build the Docker image.
3. Login to Amazon ECR and push the image.
4. Create or update the Lambda function and its Function URL (configured in `BUFFERED` mode for Stateless HTTP).

## Monitoring Status
You can check the remote Lambda function status:
```bash
make status
```
Or specifically for Lambda:
```bash
make lambda-status
```
To get the public Function URL:
```bash
make endpoint
```

## Tools

### `greet`
- **Description:** Get a greeting from the local server.
- **Parameters:**
    - `param` (string): The text or name to echo back.
- **Returns:** The string passed in `param`.

## Development Tasks

- **`make status`**: Show AWS Lambda function status.
- **`make git-status`**: Show local git status.
- **`make lint`**: Check code style (flake8).
- **`make format`**: Auto-format code (black).
- **`make clean`**: Remove build artifacts and virtual environments.

## Project Structure

- `main.py`: FastMCP server definition with Mangum handler for Lambda.
- `Makefile`: Centralized automation for dev, test, and AWS Lambda deployment.
- `Dockerfile`: Container definition based on the AWS Lambda Python base image.
- `save-aws-creds.sh`: Helper for managing AWS session credentials.
