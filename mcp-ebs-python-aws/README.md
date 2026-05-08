# MCP HTTP Python Server for AWS Elastic Beanstalk (Docker)

A Model Context Protocol (MCP) server implemented in Python using `FastMCP`, configured for deployment on **AWS Elastic Beanstalk** using Docker containers.

## Overview

This project provides an MCP server named `mcp-server-eb` that exposes a `greet` tool. It is containerized and deployed to Elastic Beanstalk, which handles scaling, load balancing, and health monitoring automatically.

### Architecture Highlights

- **Compute:** [AWS Elastic Beanstalk](https://aws.amazon.com/elasticbeanstalk/) with the Docker platform.
- **Transport:** SSE over HTTP (Stateless).
- **Infrastrucure as Code:** Managed via the **AWS EB CLI**.
- **Containerized:** Based on `python:3.13-slim`.

## Prerequisites

- **Python 3.10+**
- **AWS CLI** configured with appropriate permissions.
- **AWS EB CLI** installed (`pip install awsebcli`).
- **Docker** installed and running.

## Installation

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd mcp-ebs-python-aws
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
2.  Initializes Elastic Beanstalk (if not already done).
3.  Creates the EB environment (if it doesn't exist).
4.  Deploys the application using the EB CLI.

## Endpoints

- **Root (`/`):** Returns a JSON response indicating the server is running and listing available endpoints.
- **Health Check (`/health`):** Returns `{"status": "healthy"}`. Used by Elastic Beanstalk for monitoring.
- **MCP SSE (`/mcp/`):** The endpoint for the Model Context Protocol over SSE.

## Monitoring & Status
Check the status of your deployment:
```bash
make status
```
To get the public environment endpoint:
```bash
make endpoint
```

## MCP Configuration
To use this server with an MCP client (like Claude Desktop), use the following configuration, replacing `<URL>` with the output of `make endpoint`:

```json
{
  "mcpServers": {
    "eb-aws": {
      "command": "curl",
      "args": ["-N", "<URL>/mcp/"]
    }
  }
}
```
*Note: Ensure you include the `/mcp/` path and the `-N` (no-buffer) flag for curl.*

## Tools

### `greet`
- **Description:** Get a greeting from the local server.
- **Parameters:**
    - `param` (string): The text or name to echo back.
- **Returns:** A friendly greeting string.

## Development Commands

- **`make test`**: Run the test suite.
- **`make status`**: Show Elastic Beanstalk environment status and events.
- **`make endpoint`**: Display the public environment URL.
- **`make lint`**: Check code style (flake8).
- **`make format`**: Auto-format code (black).
- **`make aws-destroy`**: Terminate the Elastic Beanstalk environment to stop billing.
