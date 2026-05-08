# Gemini Code Assistant Context

This document provides context for the Gemini Code Assistant to understand the project and assist in development.

## Project Overview

This is a **Python-based Model Context Protocol (MCP) server** using the `FastMCP` class from the `mcp` SDK. It is designed to expose tools (like `greet`) over HTTP/SSE for integration with MCP clients.

The server is implemented as a **Starlette** application, providing a robust and asynchronous foundation for both the MCP protocol and standard HTTP endpoints.

### Core Components

*   **FastMCP:** Initializes the MCP server (named `mcp-lambda-python-aws` in code).
*   **Starlette App:** Wraps the MCP HTTP app and adds custom routes:
    *   `/`: Root informational endpoint.
    *   `/health`: Health check for Elastic Beanstalk.
    *   `/mcp`: Mount point for the MCP SSE transport.

## Key Technologies

*   **Language:** Python 3.13
*   **SDK:** `mcp` (Model Context Protocol SDK)
*   **Library:** `FastMCP` (for simplified server creation)
*   **Hosting:** **AWS Elastic Beanstalk (EB)**
*   **Platform:** **Docker** (using the EB Docker platform)
*   **Transport:** **Stateless HTTP**
*   **Networking:** Automatically managed by Elastic Beanstalk (Load Balancer, Auto Scaling Group).
*   **Logging:** Python `logging` to stdout/stderr, captured by EB.
*   **Dependency Management:** `pip` / `requirements.txt`
*   **Deployment:** Managed via the **AWS EB CLI** (`eb` commands).

### Why Elastic Beanstalk?
Elastic Beanstalk provides a Platform-as-a-Service (PaaS) experience for Docker containers. It simplifies infrastructure management by automatically handling deployment, capacity provisioning, load balancing, and auto-scaling.

### Deployment Setup

1.  **Install EB CLI:**
    ```bash
    pip install awsebcli
    ```

2.  **Update Credentials:**
    ```bash
    ./save-aws-creds.sh
    ```

3.  **Deploy:**
    ```bash
    make deploy
    ```

## Project Structure

*   `main.py`: The entry point. Initializes FastMCP and Starlette app.
*   `deploy.sh`: Script to manage the EB deployment lifecycle.
*   `destroy.sh`: Clean teardown script using `eb terminate`.
*   `requirements.txt`: Python dependencies.
*   `Makefile`: Automation entry point.
*   `Dockerfile`: Container definition based on `python:3.13-slim`.

## Makefile Commands

- **Monitoring:**
    - `make status`: Shows EB environment status and recent events.
    - `make endpoint`: Gets the public EB environment URL.
- **Deployment:**
    - `make deploy`: Full deployment cycle (Tests -> EB Init/Create/Deploy).
    - `make docker-build`: Build the container image locally.
- **Teardown:**
    - `make aws-destroy`: Terminates the EB environment to stop billing.
