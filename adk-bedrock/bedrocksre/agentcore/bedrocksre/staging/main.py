from typing import Any

from bedrock_agentcore.runtime import BedrockAgentCoreApp
from agent import root_agent

app = BedrockAgentCoreApp()
log = app.logger

@app.entrypoint
async def invoke(payload, context):
    log.info("Invoking ADK Agent via AgentCore.....")
    
    prompt = payload.get("prompt")
    if not prompt:
        yield "Error: No prompt provided"
        return

    # Use ADK Agent to execute (streaming)
    try:
        # root_agent.stream_async returns an async iterator of events
        async for event in root_agent.stream_async(prompt):
            # ADK stream events are usually objects with 'text' or 'data'
            # Looking at standard ADK patterns, we check for event data
            if hasattr(event, 'data') and isinstance(event.data, str):
                yield event.data
            elif isinstance(event, str):
                yield event
            elif hasattr(event, 'text'):
                yield event.text
    except Exception as e:
        log.error(f"Error during invocation: {e}")
        yield f"Error: {str(e)}"

if __name__ == "__main__":
    app.run()
