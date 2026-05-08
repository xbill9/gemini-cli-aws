from typing import Any

from bedrock_agentcore.runtime import BedrockAgentCoreApp
from google.adk.runners import Runner
from google.adk.sessions import InMemorySessionService
from google.genai import types
from agent import root_agent

app = BedrockAgentCoreApp()
log = app.logger

# Initialize ADK Runner
session_service = InMemorySessionService()
runner = Runner(
    agent=root_agent,
    app_name="bedrocksre",
    session_service=session_service
)

@app.entrypoint
async def invoke(payload, context):
    log.info("Invoking ADK Agent via AgentCore Runner.....")
    
    prompt = payload.get("prompt")
    if not prompt:
        yield "Error: No prompt provided"
        return

    # Create user message content
    user_content = types.Content(role='user', parts=[types.Part(text=prompt)])
    
    # We use a static user/session ID for now, or could derive from context if available
    user_id = payload.get("user_id", "default_user")
    session_id = payload.get("session_id", "default_session")

    # Ensure session exists (or run_async will fail if it's the first time and we don't handle it)
    # Actually Runner.run_async creates a session if it doesn't exist? 
    # Let's check. Usually we need to create it first or use a service that auto-creates.
    try:
        await session_service.create_session(app_name="bedrocksre", user_id=user_id, session_id=session_id)
    except Exception:
        pass # Session might already exist

    # Use ADK Runner to execute
    try:
        async for event in runner.run_async(
            user_id=user_id,
            session_id=session_id,
            new_message=user_content
        ):
            # Check for text in parts
            if event.content and event.content.parts:
                for part in event.content.parts:
                    if part.text:
                        yield part.text
    except Exception as e:
        log.error(f"Error during invocation: {e}")
        yield f"Error: {str(e)}"

if __name__ == "__main__":
    app.run()
