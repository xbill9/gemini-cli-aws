# main.py

import asyncio
import logging
import sys
import os
from contextlib import asynccontextmanager

from pythonjsonlogger.json import JsonFormatter
from fastmcp import FastMCP
from starlette.responses import JSONResponse
from starlette.applications import Starlette
from starlette.routing import Route, Mount
from mangum import Mangum

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)
formatter = JsonFormatter()

stderr_handler = logging.StreamHandler(sys.stderr)
stderr_handler.setFormatter(formatter)
stderr_handler.setLevel(logging.INFO)
logger.addHandler(stderr_handler)

# Initialize FastMCP server
mcp = FastMCP("mcp-lambda-python-aws")

@mcp.tool()
def greet(param: str) -> str:
    """
    Get a greeting from a local server.
    """
    logger.info(f"Greeting {param}")
    return f"Hello, {param}!"

async def health_check(request):
    return JSONResponse({"status": "healthy", "service": "mcp-server"})

async def root_path(request):
    return JSONResponse({
        "message": "MCP Server is running",
        "endpoints": ["/health", "/mcp/"],
        "help": "Use /mcp/ for the MCP SSE transport"
    })

# Get the FastMCP ASGI application with stateless mode
app = mcp.http_app(path="/mcp", stateless_http=True)

# Add custom routes directly to the FastMCP app
app.add_route("/health", health_check, methods=["GET"])
app.add_route("/", root_path, methods=["GET"])

# Save the original lifespan context manager factory
original_lifespan = app.lifespan

# Custom lifespan for Lambda to keep MCP initialized across requests
_mcp_started = False
_mcp_lifespan_cm = None

@asynccontextmanager
async def lambda_lifespan(app):
    global _mcp_started, _mcp_lifespan_cm
    if not _mcp_started:
        try:
            # Manually enter the original lifespan context manager
            # and don't exit it to keep the task group alive across Lambda calls.
            _mcp_lifespan_cm = original_lifespan(app)
            await _mcp_lifespan_cm.__aenter__()
            _mcp_started = True
            logger.info("✅ MCP Lifespan initialized (persistent)")
        except Exception as e:
            logger.error(f"❌ Failed to initialize MCP Lifespan: {e}")
            raise
    yield
    # We skip __aexit__ to keep the session manager running in the warm container

# Use our custom lifespan
app.router.lifespan_context = lambda_lifespan

# Wrap the main app with Mangum
handler = Mangum(app, lifespan="on")

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8080))
    logger.info(f"🚀 MCP server started on port {port}")
    
    mcp.run(
        transport="http",
        host="0.0.0.0",
        port=port,
    )
