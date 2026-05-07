import os
from strands.models.bedrock import BedrockModel

DEFAULT_MODEL_ID = "global.anthropic.claude-sonnet-4-5-20250929-v1:0"


def load_model() -> BedrockModel:
    """Get Bedrock model client using IAM credentials."""
    model_id = os.environ.get("MODEL_ID", DEFAULT_MODEL_ID)
    return BedrockModel(
        model_id=model_id,
    )
