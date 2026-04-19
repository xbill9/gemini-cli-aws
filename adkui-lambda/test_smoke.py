import os
from dotenv import load_dotenv

def test_env_loading():
    """Verify that environment variables can be loaded from .env."""
    load_dotenv()
    # Check for core project setting
    project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
    assert project_id is not None, "GOOGLE_CLOUD_PROJECT should be set in .env"

def test_directory_structure():
    """Verify that essential project directories exist."""
    essential_dirs = ["Agent1", "Agent2", "Agent3", "Agent4"]
    for d in essential_dirs:
        assert os.path.isdir(d), f"Directory {d} should exist"

def test_agent_configs():
    """Verify that agent config files exist and are readable."""
    configs = [
        "Agent1/root_agent.yaml",
        "Agent2/root_agent.yaml",
        "Agent3/root_agent.yaml",
        "Agent4/root_agent.yaml"
    ]
    for cfg in configs:
        assert os.path.isfile(cfg), f"Config file {cfg} should exist"
        with open(cfg, 'r') as f:
            content = f.read()
            assert len(content) > 0, f"Config file {cfg} should not be empty"
