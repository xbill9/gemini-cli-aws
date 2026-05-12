# mcp-eks-rust-aws

A Rust-based Model Context Protocol (MCP) server designed for deployment on Amazon EKS (Elastic Kubernetes Service), utilizing streaming HTTP.

## Overview

This project implements an MCP server using the [`rmcp`](https://github.com/modelcontextprotocol/rust-sdk) library and the [`axum`](https://docs.rs/axum/latest/axum/) web framework. It provides a `greeting` tool and is optimized for high-performance, streaming communication over HTTP.

## Features

- **MCP Tooling**: Implements a `greeting` tool.
- **Streaming HTTP**: Uses `rmcp`'s `StreamableHttpService` for efficient JSON-RPC over HTTP.
- **EKS Deployment**: Pre-configured for Amazon EKS using managed node groups.
- **Graceful Shutdown**: Handles SIGINT and SIGTERM for clean exits.

## Getting Started

### Prerequisites

- [Rust Toolchain](https://www.rust-lang.org/tools/install) (2024 edition)
- [Docker](https://docs.docker.com/get-docker/) (for containerization)
- [AWS CLI](https://aws.amazon.com/cli/) (configured with appropriate credentials)
- [eksctl](https://eksctl.io/) (for cluster management)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (for interacting with the cluster)

### Build

To build the project for release:

```bash
cargo build --release
```

### Run Locally

The server listens on the port specified by the `PORT` environment variable (default: `8080`).

```bash
# Using Makefile
make run

# Or directly
cargo run --release
```

The server will be available at `http://localhost:8080`.
You can check the health at `http://localhost:8080/health`.

### Development Targets

The `Makefile` provides several useful targets:

- `make test`: Run unit tests.
- `make clippy`: Run linting checks.
- `make fmt`: Check code formatting.
- `make start`: Start the server in the background (logs to `server.log`).
- `make stop`: Stop the background server.
- `make status`: Check the status of the background server.

## Deployment

To deploy the application to Amazon EKS:

```bash
# Create the cluster (one-time setup, takes ~15-20 mins)
make cluster-create

# Deploy the application
make deploy
```

This will build the Docker image, push it to Amazon ECR, and deploy the Kubernetes manifests to the EKS cluster.

### Status

To check the deployment status and get the public URL:

```bash
make eks-status
make endpoint
```

### Logs

To monitor logs from the EKS pods:

```bash
make logs
```

## Protocol Details

This implementation follows the Model Context Protocol (MCP) using the streaming HTTP transport. Sessions are managed locally via `LocalSessionManager`.

## License

MIT
