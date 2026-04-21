import os
import logging
from google.adk.tools import ToolContext

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


async def assemble_and_write_html(gallery: list, tool_context: ToolContext) -> str:
    """
    Logs the tool_context for debugging purposes.
    """
    try:
        logger.info(f"Tool context received: {tool_context}")
        logger.info(f"Tool context type: {type(tool_context)}")
        logger.info(f"Tool context dir: {dir(tool_context)}")
        # Try to access user_id and session_id to see if they exist
        user_id = getattr(tool_context, 'user_id', 'NOT_FOUND')
        session_id = getattr(tool_context, 'session_id', 'NOT_FOUND')
        logger.info(f"User ID from context: {user_id}")
        logger.info(f"Session ID from context: {session_id}")
        return "Logged tool context for debugging."
    except Exception as e:
        logger.exception("Failed to log tool context.")
        return f"An error occurred while logging tool context: {e}"
