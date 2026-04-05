# Gemini Code Assistant Context

This document provides context for the Gemini Code Assistant to understand the ADK (Agent Development Kit) project for building an agentic comic book pipeline.

## Project Overview

This project implements a multi-agent system using the **Google ADK** to automate the creation of comic books. It follows a sequential pipeline where specialized agents handle scripting, panelization, image synthesis, and assembly. It also supports multi-cloud deployment to Google Cloud and AWS (ECS Express Mode).

It is based on the solution to the codelab: [Create a low-code agent with ADK visual builder](https://codelabs.developers.google.com/codelabs/create-low-code-agent-with-ADK-visual-builder)

## Key Technologies

*   **Framework:** Google ADK (Agent Development Kit) [Docs](https://google.github.io/adk-docs/)
*   **Language:** Python 3
*   **Generative AI:** Vertex AI (GenAI SDK)
*   **Cloud Platforms:** Google Cloud (Run, Vertex AI), AWS (ECS Express Mode)
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
    *   `Makefile`: Primary entry point for ECS Express Mode deployment.
    *   `save-aws-creds.sh`: Utility to export AWS credentials to `.aws_creds`.
    *   `deploycloudrun.py`: Script for Google Cloud Run deployment.
    *   `Dockerfile`: Multi-stage build for deploying the ADK application.
    *   `deploy-lightsail.sh`: (Legacy) Script for Amazon Lightsail deployment.
*   **Utility**:
    *   `init.sh`: Project initialization script.
    *   `comic.sh`: Local server for viewing comics.
    *   `fix_comic.py`: HTML regeneration utility.

## Makefile Commands

*   **ECS Express Mode (Recommended)**:
    *   `make deploy`: Full deployment cycle (ECR push + ECS deploy). Refreshes AWS credentials automatically.
    *   `make status`: Monitor the ECS Express service state and active revisions.
    *   `make endpoint`: Get the public URL of the ECS service.
    *   `make aws-destroy`: Tear down ECS resources.
*   **Legacy Lightsail**:
    *   `make deploy-lightsail`: Legacy deployment to Lightsail.
    *   `make lightsail-status`: Monitor Lightsail service.
*   **General**:
    *   `make clean`: Purge logs and generated images.

## Known Bugs & Workarounds

*   **AWS Token Expiration**: Long-running commands like `make deploy` (especially with `--monitor-resources`) can trigger `ExpiredTokenException`. The `Makefile` includes `save-aws-creds.sh` to refresh tokens.
*   **ECS Health Checks**: The ADK UI redirects `/` to `/agent/Agent1`, causing health check failures (307 vs expected 200). The `Makefile` overrides the health check path to `/docs` which returns a `200 OK`.
*   **ECS Network State**: `aws ecs update-express-gateway-service` may reset security groups and subnets if not explicitly provided. The `Makefile` dynamically fetches the existing `networkConfiguration` using `jq` and reapplies it during updates.
*   **YAML Nesting**: The ADK CLI may nest YAML configurations in subdirectories incorrectly. They must be moved to the root of the respective agent's directory.

## Workflow (Agent3)

1.  **Scripting**: Seed idea -> script + character manifest.
2.  **Panelization**: Script -> 8 distinct 16:9 panels with descriptions.
3.  **Image Synthesis**: Panel descriptions -> Vertex AI generated images.
4.  **Assembly**: Images + Script -> responsive HTML layout (`output/comic.html`).
5.  **Inspection (Agent4)**: Summarize and export to ADK Artifacts.
