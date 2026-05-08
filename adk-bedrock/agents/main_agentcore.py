import os
from strands import Agent
from strands.models.bedrock import BedrockModel
from bedrock_agentcore.runtime import BedrockAgentCoreApp

app = BedrockAgentCoreApp()
log = app.logger

# Initialize the model and agent
# Note: Using nova-micro for fast responses
bedrock_model_id = os.getenv("BEDROCK_MODEL", "amazon.nova-micro-v1:0")
model = BedrockModel(model_id=bedrock_model_id)
agent = Agent(
    model=model,
    system_prompt="You are a helpful assistant powered by Amazon Bedrock."
)

@app.entrypoint
async def invoke(payload, context):
    log.info(f"Invoking Bedrock Agent ({bedrock_model_id}) via AgentCore (Strands).....")
    
    prompt = payload.get("prompt")
    if not prompt:
        yield "Error: No prompt provided"
        return

    # Use Strands Agent to execute (streaming)
    try:
        stream = agent.stream_async(prompt)
        async for event in stream:
            if "data" in event and isinstance(event["data"], str):
                yield event["data"]
    except Exception as e:
        log.error(f"Error during invocation: {e}")
        yield f"Error: {str(e)}"

if __name__ == "__main__":
    app.run()
