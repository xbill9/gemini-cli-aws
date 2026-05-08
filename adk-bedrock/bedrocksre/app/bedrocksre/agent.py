import os

from google.adk.agents import LlmAgent
from google.adk.models.lite_llm import LiteLlm

# --- Example Agent using Amazon Bedrock ---

# Model name for Bedrock
bedrock_model = os.getenv("BEDROCK_MODEL", "bedrock/amazon.nova-micro-v1:0")

root_agent = LlmAgent(
    model=LiteLlm(model=bedrock_model),
    name="bedrock_agent",
    instruction="You are a helpful assistant powered by Amazon Bedrock and the Agent Developer Kit (ADK).",
    # ... other agent parameters
)
