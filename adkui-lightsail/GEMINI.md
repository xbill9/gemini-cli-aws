# Gemini Code Assistant Context

This document provides context for the Gemini Code Assistant to understand the ADK (Agent Development Kit) project for building an agentic comic book pipeline.

## Project Overview

This project implements a multi-agent system using the **Google ADK** to automate the creation of comic books. It follows a sequential pipeline where specialized agents handle scripting, panelization, image synthesis, and assembly. It also supports multi-cloud deployment to Google Cloud and AWS.

It is based on the solution to the codelab: [Create a low-code agent with ADK visual builder](https://codelabs.developers.google.com/codelabs/create-low-code-agent-with-ADK-visual-builder)

## Key Technologies

*   **Framework:** Google ADK (Agent Development Kit) [Docs](https://google.github.io/adk-docs/)
*   **Language:** Python 3
*   **Generative AI:** Vertex AI (GenAI SDK)
*   **Cloud Platforms:** Google Cloud (Run, Vertex AI), AWS (Lightsail Containers)
*   **Models:**
    *   **LLM Tasks:** `gemini-2.5-flash` (used for narrative and layout planning).
    *   **Image Gen:** `imagen-3.0-fast-generate-001`.
*   **Environment:** `.env` for Google Cloud and AWS configuration.

**Important:** Do not suggest `gemini-2.0` models; they are deprecated.

## Project Structure

*   `Agent1/`: Simple agent with a Google Search tool. Uses `root_agent.yaml`.
*   `Agent2/`: Image generation agent demonstrating sub-agent coordination.
*   `Agent3/`: Primary comic pipeline implementation (Sequential Pipeline).
    *   `root_agent.yaml`: Studio Director.
    *   `comic_pipeline_agent.yaml`: Orchestrator.
    *   `scripting_agent.yaml`, `panelization_agent.yaml`, `image_synthesis_agent.yaml`, `assembly_agent.yaml`: Specialized stage agents.
    *   `tools/`: `image_generation.py` (Vertex AI) and `file_writer.py` (HTML generation).
*   `Agent4/`: Comic Reader agent.
    *   `tools/comic_reader.py`: Tools for listing, summarizing, and exporting comics as ADK artifacts.
*   `images/` & `output/`: Local storage for generated assets and final `comic.html`.

## Tools & Scripts

*   **ADK Development**:
    *   `agent_builder`: Launches the ADK Builder UI.
    *   `myadk`: Wrapper for `adk` CLI.
*   **Deployment**:
    *   `deploy-lightsail.sh`: Main script for Amazon Lightsail deployment.
    *   `save-aws-creds.sh`: Utility to export AWS credentials to `.aws_creds`.
    *   `deploycloudrun.py`: Script for Google Cloud Run deployment.
    *   `Dockerfile`: Multi-stage build for deploying the ADK application.
*   **Utility**:
    *   `init.sh`: Project initialization script.
    *   `comic.sh`: Local server for viewing comics.
    *   `fix_comic.py`: HTML regeneration utility.

## Makefile Commands

*   `make deploy`: Primary command for AWS Lightsail deployment (saves creds + deploys).
*   `make lightsail-status`: Monitor the AWS deployment state.
*   `make clean`: Purge logs and generated images.

## Known Bugs & Workarounds

*   **Environment Variables:** After editing `.env`, you must `source .env` or run `./set_env.sh`.
*   **YAML Nesting:** The ADK CLI may nest YAML configurations in subdirectories incorrectly. They must be moved to the root of the respective agent's directory.
*   **Issue Tracker:** Refer to [adk-python Issue #4134](https://github.com/google/adk-python/issues/4134).

## Workflow (Agent3)

1.  **Scripting**: Seed idea -> script + character manifest.
2.  **Panelization**: Script -> 8 distinct 16:9 panels with descriptions.
3.  **Image Synthesis**: Panel descriptions -> Vertex AI generated images.
4.  **Assembly**: Images + Script -> responsive HTML layout (`output/comic.html`).
5.  **Inspection (Agent4)**: Summarize and export to ADK Artifacts.
