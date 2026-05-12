use anyhow::Result;
use axum::{Json, routing::get};
use rmcp::{
    handler::server::{ServerHandler, tool::ToolRouter, wrapper::Parameters},
    model::{ServerCapabilities, ServerInfo},
    schemars, tool, tool_handler, tool_router,
    transport::streamable_http_server::{
        StreamableHttpServerConfig, StreamableHttpService, session::local::LocalSessionManager,
    },
};
use serde::{Deserialize, Serialize};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

/// Request structure for the greeting tools
#[derive(Debug, Deserialize, schemars::JsonSchema)]
struct GreetRequest {
    /// The message or name to greet
    #[schemars(description = "The name or message to greet")]
    pub message: String,
}

/// Response structure for HTTP health and root endpoints
#[derive(Serialize)]
struct StatusResponse {
    status: String,
    service: String,
}

#[derive(Serialize)]
struct RootResponse {
    message: String,
    endpoints: Vec<String>,
    help: String,
}

/// The main application state and handler for the MCP server
#[derive(Clone)]
struct HelloWorld {
    /// Router for MCP tools
    #[allow(dead_code)]
    tool_router: ToolRouter<Self>,
}

#[tool_router]
impl HelloWorld {
    /// Creates a new instance of the HelloWorld server handler
    fn new() -> Self {
        Self {
            tool_router: Self::tool_router(),
        }
    }

    /// Echoes back a message with a friendly greeting
    #[tool(description = "Echoes back a message with a friendly greeting")]
    async fn greeting(
        &self,
        Parameters(GreetRequest { message }): Parameters<GreetRequest>,
    ) -> String {
        tracing::info!("Greeting (mcp): {}", message);
        format!("Hello World MCP! {}", message)
    }

    /// Get a greeting from the server (matches Python example name)
    #[tool(description = "Get a greeting from the server")]
    async fn greet(
        &self,
        Parameters(GreetRequest { message }): Parameters<GreetRequest>,
    ) -> String {
        tracing::info!("Greeting (greet): {}", message);
        format!("Hello, {}!", message)
    }
}

#[tool_handler]
impl ServerHandler for HelloWorld {
    fn get_info(&self) -> ServerInfo {
        ServerInfo::new(ServerCapabilities::builder().enable_tools().build())
            .with_instructions("A streaming HTTP MCP server in Rust")
    }
}

async fn health_check() -> Json<StatusResponse> {
    Json(StatusResponse {
        status: "healthy".to_string(),
        service: "mcp-server-rust".to_string(),
    })
}

async fn root_path() -> Json<RootResponse> {
    Json(RootResponse {
        message: "Rust MCP Server is running".to_string(),
        endpoints: vec!["/health".to_string(), "/".to_string()],
        help: "This server provides MCP tools via streaming HTTP transport. Use an MCP client to connect.".to_string(),
    })
}

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing subscriber for logging
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info,mcp_lambda_rust_aws=debug".into()),
        )
        .with(
            tracing_subscriber::fmt::layer()
                .with_writer(std::io::stderr)
                .pretty(),
        )
        .init();

    let service_factory = || Ok(HelloWorld::new());
    let session_manager = LocalSessionManager::default();

    // Configure allowed hosts for DNS rebinding protection
    let mut config = StreamableHttpServerConfig::default();
    if let Ok(hosts_str) = std::env::var("ALLOWED_HOSTS") {
        tracing::info!("ALLOWED_HOSTS env set: {}", hosts_str);
        let hosts: Vec<String> = hosts_str.split(',').map(String::from).collect();
        if hosts.iter().any(|h| h == "*") {
            tracing::info!("Wildcard '*' detected in ALLOWED_HOSTS, disabling host check");
            config.allowed_hosts = vec![];
        } else {
            config.allowed_hosts = hosts;
        }
    } else {
        // Default allowed hosts
        config.allowed_hosts = vec![
            "0.0.0.0".to_string(),
            "localhost".to_string(),
            "127.0.0.1".to_string(),
        ];
    }

    let service = StreamableHttpService::new(service_factory, session_manager.into(), config);

    // Build Axum router with JSON responses for health and root
    let app = axum::Router::new()
        .route("/", get(root_path))
        .route("/health", get(health_check))
        .fallback_service(service);

    // Determine port from environment variable
    let port = std::env::var("PORT").unwrap_or_else(|_| "8080".to_string());
    let addr = format!("0.0.0.0:{}", port);
    let listener = tokio::net::TcpListener::bind(&addr).await?;

    tracing::info!("🚀 Rust MCP Server listening on http://{}", addr);

    // Run with graceful shutdown
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await?;

    Ok(())
}

/// Handles graceful shutdown for SIGINT and SIGTERM
async fn shutdown_signal() {
    let ctrl_c = async {
        tokio::signal::ctrl_c()
            .await
            .expect("failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            .expect("failed to install signal handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }

    tracing::info!("Signal received, starting graceful shutdown...");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_greeting() {
        let hello = HelloWorld::new();
        let request = GreetRequest {
            message: "Tester".to_string(),
        };
        let response = hello.greeting(Parameters(request)).await;
        assert_eq!(response, "Hello World MCP! Tester");
    }

    #[tokio::test]
    async fn test_greet() {
        let hello = HelloWorld::new();
        let request = GreetRequest {
            message: "Gemini".to_string(),
        };
        let response = hello.greet(Parameters(request)).await;
        assert_eq!(response, "Hello, Gemini!");
    }
}
