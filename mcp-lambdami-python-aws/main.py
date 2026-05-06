# main.py

import logging
import sys
import os

from fastmcp import FastMCP
from starlette.responses import JSONResponse
from starlette.applications import Starlette
from starlette.routing import Route, Mount

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    stream=sys.stderr,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

logger.info("🎬 main.py loaded")

# Initialize FastMCP server
mcp = FastMCP("mcp-lambda-python-aws")


@mcp.tool()
def greet(param: str) -> str:
    """
    Get a greeting from a local server.
    """
    logger.info(f"👋 Greeting {param}")
    return f"Hello, {param}!"


async def health_check(request):
    logger.info("🏥 Received health check")
    return JSONResponse({"status": "healthy", "service": "mcp-server"})


async def root_path(request):
    logger.info("🏠 Received root path request")
    return JSONResponse(
        {
            "message": "MCP Server is running",
            "endpoints": ["/health", "/mcp/"],
            "help": "Use /mcp/ for the MCP SSE transport",
        }
    )


# Get the FastMCP ASGI application with stateless mode
mcp_app = mcp.http_app(path="/", stateless_http=True)

# Create the main Starlette application
app = Starlette(
    routes=[
        Route("/", root_path, methods=["GET"]),
        Route("/health", health_check, methods=["GET"]),
        Mount("/mcp", mcp_app),
    ],
    lifespan=mcp_app.lifespan,
)

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8080))
    logger.info(f"🚀 MCP server started on port {port}")

    mcp.run(
        transport="http",
        host="0.0.0.0",
        port=port,
    )
