# Gemini Workspace for `mcp-lambda-rust-aws`

You are a Rust Developer working with Amazon AWS.
Follow Rust best practices and idiomatic patterns (2024 edition).

## Project Overview

`mcp-lambda-rust-aws` is a streaming HTTP MCP server written in Rust, designed for deployment on AWS Lambda using Container Images and Lambda Function URLs. It uses the `rmcp` library to provide tools to LLM agents via the Model Context Protocol.

### Key Technologies

*   **Language:** Rust (2024 Edition)
*   **MCP Framework:** [`rmcp`](https://github.com/modelcontextprotocol/rust-sdk) (v1.6.0)
*   **Web Framework:** [Axum](https://docs.rs/axum/latest/axum/) (v0.8.9)
*   **Containerization:** Docker (AWS ECR)
*   **Deployment:** AWS Lambda (Function URL)
*   **Runtime Adapter:** [AWS Lambda Adapter](https://github.com/awslabs/aws-lambda-adapter)

## Development Workflow

### Useful Commands

- `make build`: Compiles the project locally.
- `make run`: Starts the server locally on port 8080.
- `make test`: Runs unit tests in `src/main.rs`.
- `make clippy`: Runs linting.
- `make format`: Formats the code.
- `make deploy`: (Recommended) Builds Docker image, pushes to ECR, and deploys to AWS Lambda.
- `make lambda`: Alias for `make deploy`.
- `make status`: Check Lambda deployment status.
- `make endpoint`: Get the public Lambda Function URL.
- `make aws-destroy`: Destroy all created AWS resources (Lambda, ECR, IAM).

### Implementation Details

- **Entry Point:** `src/main.rs` defines the `HelloWorld` struct which implements `ServerHandler`.
- **Lambda Integration:** Uses `aws-lambda-adapter` to wrap the Axum web server for Lambda.
- **Function URL:** Deployed with `BUFFERED` invoke mode for stateless HTTP compatibility.
- **Health Check:** A `/health` endpoint is provided.
- **Environment Variables:**
    - `PORT`: Determines the listening port (default: 8080, used by Lambda Adapter).
    - `ALLOWED_HOSTS`: Comma-separated list of allowed hostnames. Use `*` for Lambda Function URLs.

## Documentation References

- [rmcp Documentation](https://docs.rs/rmcp/latest/rmcp/)
- [Axum Documentation](https://docs.rs/axum/latest/axum/)
- [AWS Lambda Adapter](https://github.com/awslabs/aws-lambda-adapter)
- [Model Context Protocol Specification](https://modelcontextprotocol.io/)

## Tips for Gemini

- **Adding Tools:** Use the `#[tool]` attribute in the `HelloWorld` impl block. Ensure the `tool_router` is correctly initialized in `new()`.
- **Tool Parameters:** Ensure all parameter structs implement `serde::Deserialize` and `schemars::JsonSchema`.
- **Local Sessions:** The `LocalSessionManager` handles MCP session state locally.
- **Tracing:** Use `tracing` for logging. The subscriber is initialized in `main`.
