# server.py

import logging
import sys
import os

from pythonjsonlogger.json import JsonFormatter
from mcp.server.fastmcp import FastMCP
from starlette.responses import JSONResponse

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)  # Set the root logger level
formatter = JsonFormatter()

# Handler for all levels to stderr
stderr_handler = logging.StreamHandler(sys.stderr)
stderr_handler.setFormatter(formatter)
stderr_handler.setLevel(logging.INFO)  # Capture all levels from INFO up
logger.addHandler(stderr_handler)

# Get port from environment
port = int(os.environ.get("PORT", 8000))

# Initialize FastMCP server with AgentCore compatible settings
mcp = FastMCP(
    "hello_world_server", host="0.0.0.0", port=port, stateless_http=True
)


# health check on standard http endpoint
@mcp.custom_route("/health", methods=["GET"])
async def health_check(request):
    logger.info("Health check requested")
    return JSONResponse({"status": "healthy", "service": "mcp-server"})


@mcp.tool()
def greet(param: str) -> str:
    """
    Echoes the input parameter back as a greeting.

    Args:
        param: The name or message to be echoed by the server.
    """
    logger.info(f"Executed greet tool with param: {param}")
    # FastMCP automatically wraps the return value in TextContent
    return param


if __name__ == "__main__":
    logger.info(f"🚀 MCP server starting on port {port}")

    mcp.run(transport="streamable-http")
