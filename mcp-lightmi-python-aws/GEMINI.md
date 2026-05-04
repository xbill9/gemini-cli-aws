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
    - `make status`: Shows git status, Lightsail container status, and Lightsail instance status.
    - `make git-status`: Shows only git status.
    - `make lightsail-status`: Queries AWS for the current Lightsail container service state.
    - `make instance-status`: Queries AWS for the current Lightsail instance state.
- **Deployment:**
    - `make deploy`: Primary deployment target. Deploys to a Lightsail Managed Instance (VPS).
    - `make instance-deploy`: Deploys to a Lightsail Managed Instance (creates instance, sets firewall, syncs code).
    - `make instance-sync`: Syncs local code to the Lightsail instance and restarts the service.
    - `make lightsail`: Deploys to Lightsail Container Services (legacy/alternative).
- **Code Quality:**
    - `make test`: Run pytest suite.
    - `make lint`: Run flake8.
    - `make format`: Run black.
    - `make type-check`: Run mypy.
- **Cleanup:**
    - `make destroy`: Destroys all AWS resources (both Lightsail container and instance).
    - `make aws-destroy`: Alias for `make destroy`.
    - `make instance-destroy`: Destroys only the Lightsail instance and local key file.

## Deployment Environment

The project is primarily configured for deployment to **Amazon Lightsail Managed Instances (VPS)**, but also supports **Amazon Lightsail Container Services**.

### Managed Instance (VPS) Deployment
This method runs the Python MCP server directly on an Amazon Lightsail instance as a `systemd` service.

- **Blueprint:** Debian 13 (Default)
- **Bundle:** Nano (0.5 GB RAM, 1 vCPU)
- **Port:** 8080 (HTTP)
- **Service Management:** `systemd` (service name: `mcp-server`)
- **Default SSH User:** `admin` (for Debian)

### Container Service Deployment (Alternative)
The project can also be deployed to Lightsail Container Services using the provided `Dockerfile`. Use `make lightsail` for this path.
### Prerequisites
- AWS CLI installed and configured.
- `lightsailctl` plugin installed.
- Docker installed and running.

### Lightsail Plugin (lightsailctl) Installation

The `lightsailctl` plugin is required for the AWS CLI to push container images to Lightsail.

1.  **Download the plugin binary:**
    ```bash
    # For Linux x86_64
    sudo curl "https://s3.us-west-2.amazonaws.com/lightsailctl/latest/linux-amd64/lightsailctl" -o "/usr/local/bin/lightsailctl"

    # For Linux ARM64
    # sudo curl "https://s3.us-west-2.amazonaws.com/lightsailctl/latest/linux-arm64/lightsailctl" -o "/usr/local/bin/lightsailctl"
    ```

2.  **Make it executable:**
    ```bash
    sudo chmod +x /usr/local/bin/lightsailctl
    ```

3.  **Verify installation:**
    ```bash
    lightsailctl --version
    ```

## Python MCP Developer Resources
