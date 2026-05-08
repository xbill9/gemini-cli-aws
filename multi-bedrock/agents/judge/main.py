import os
import logging
from bedrock_agentcore.runtime import BedrockAgentCoreApp
from agent import root_agent
from google.adk.runners import Runner
from google.adk.sessions import InMemorySessionService
from google.genai import types

app = BedrockAgentCoreApp()
log = app.logger

@app.entrypoint
async def invoke(payload, context):
    """
    Entrypoint for Bedrock AgentCore.
    Handles both direct invocation and A2A if protocol is configured.
    """
    # API key setup from AgentCore Identity
    api_key = os.getenv("AGENTCORE_CREDENTIAL_GEMINIAPIKEY")
    if api_key:
        os.environ["GOOGLE_API_KEY"] = api_key
        os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "FALSE"
    
    log.info(f"Invoking agent: {root_agent.name}")
    
    # Basic payload extraction
    prompt = payload.get("prompt", payload.get("message", ""))
    session_id = getattr(context, "session_id", payload.get("sessionId", "default_session"))
    user_id = payload.get("user_id", payload.get("userId", "default_user"))
    
    # ADK Runner setup
    session_service = InMemorySessionService()
    session = await session_service.create_session(
        app_name=root_agent.name, user_id=user_id, session_id=session_id
    )
    runner = Runner(agent=root_agent, app_name=root_agent.name, session_service=session_service)
    
    content = types.Content(role="user", parts=[types.Part(text=prompt)])
    events = runner.run_async(
        user_id=user_id, session_id=session.id, new_message=content
    )
    
    final_response = ""
    async for event in events:
        if event.content and event.content.parts:
            for part in event.content.parts:
                if part.text:
                    final_response += part.text
    
    return {"result": final_response}

if __name__ == "__main__":
    app.run()
