# Gemini Code Assistant Context

This document provides context for the Gemini Code Assistant to understand the ADK (Agent Development Kit) project for building an agentic comic book pipeline.

## Project Overview

This project implements a multi-agent system using the **Google ADK** to automate the creation of comic books. It follows a sequential pipeline where specialized agents handle scripting, panelization, image synthesis, and assembly.

It is based on the solution to the codelab: [Create a low-code agent with ADK visual builder](https://codelabs.developers.google.com/codelabs/create-low-code-agent-with-ADK-visual-builder)

## Key Technologies

*   **Framework:** Google ADK (Agent Development Kit) [Docs](https://google.github.io/adk-docs/)
*   **Language:** Python 3
*   **Generative AI:** Vertex AI (GenAI SDK)
*   **Models:**
    *   **LLM Tasks:** `gemini-2.5-flash` (used for narrative and layout planning).
    *   **Image Gen:** `imagen-3.0-fast-generate-001`.
*   **Environment:** `.env` for Google Cloud project configuration (project ID, location, models, etc.)

**Important:** Do not suggest `gemini-2.0` models; they are deprecated.

## Project Structure

*   `Agent1/`: Simple agent with a Google Search tool. Uses `root_agent.yaml`.
*   `Agent2/`: Image generation agent demonstrating sub-agent coordination. Uses `root_agent.yaml` and `sub_agent_*.yaml`.
*   `Agent3/`: Primary comic pipeline implementation.
    *   `root_agent.yaml`: The entry-point (Studio Director) agent.
    *   `comic_pipeline_agent.yaml`: Orchestrates the `SequentialAgent` workflow.
    *   `scripting_agent.yaml`, `panelization_agent.yaml`, `image_synthesis_agent.yaml`, `assembly_agent.yaml`: Specialized agents for each stage.
    *   `tools/`: Python implementations for ADK tools.
        *   `image_generation.py`: Interfaces with Vertex AI for 16:9 image generation.
        *   `file_writer.py`: Generates the responsive `comic.html` and saves assets.
*   `images/`: Local storage for generated panel images.
*   `output/`: Final delivery directory containing `comic.html` and necessary assets.

## Tools & Scripts

*   `agent_builder`: Launches the ADK Builder UI for visual agent development.
*   `myadk`: Convenience wrapper for the `adk` CLI tool.
*   `init.sh`: Automated setup script for GCP project initialization, API enabling, and dependency installation.
*   `deploycloudrun.py`: Script to deploy an agent (default `Agent1`) to Cloud Run.
    *   Creates a Service Account named `adkvisualbuilder`.
    *   Assigns necessary IAM roles: `aiplatform.user`, `run.admin`, `logging.logWriter`, `artifactregistry.writer`, `storage.admin`.
*   `comic.sh`: Launches a local server (`python -m http.server 8080`) in the `output/` directory for immediate viewing of generated comics.
*   `fix_comic.py`: A utility script used to regenerate `comic.html` using a default story template and `file_writer` tool.
*   `Makefile`: Shortcuts for common tasks:
    *   `make run`/`make web`: Start ADK web UI.
    *   `make clean`: Purge logs and images.
    *   `make test`: Validate comic generation locally.
    *   `make deploy`: Trigger deployment script.

## Known Bugs & Workarounds

*   **Environment Variables:** After editing `.env`, you must `source .env` or run `./set_env.sh`.
*   **YAML Nesting:** The ADK CLI may nest YAML configurations in subdirectories incorrectly. They must be moved to the root of the respective agent's directory.
*   **Issue Tracker:** Refer to [adk-python Issue #4134](https://github.com/google/adk-python/issues/4134).

* if the builder does not show add &builder=1 or ?builder=1 to the URL

## Workflow (Agent3)

1.  **Scripting**: Seed idea -> script + character manifest.
2.  **Panelization**: Script -> 8 distinct 16:9 panels with descriptions.
3.  **Image Synthesis**: Panel descriptions -> Vertex AI generated images.
4.  **Assembly**: Images + Script -> responsive HTML layout (`output/comic.html`).

## Setup & Configuration

1.  **GCP Project**: Requires `GOOGLE_CLOUD_PROJECT` and `GOOGLE_CLOUD_LOCATION` in `.env`.
2.  **Dependencies**: Managed via `requirements.txt`.
3.  **Authentication**: Use `gcloud auth application-default login` for local execution and deployment.
