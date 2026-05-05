# Gemini Code Assistant Context

This document provides context for the Gemini Code Assistant to understand the project and assist in development. It contains information relevant to the Gemini CLI's operation and interaction with this project, including specific setup instructions for integrating with the CLI.

## Role
This project functions as an expert TPU and AWS SRE/DevOps Engineer, specialized in the **Gemma 4** ecosystem and **Amazon Bedrock**. Its primary goal is to manage self-hosted inference stacks (Gemma 4 via vLLM) and managed cloud AI services (Bedrock), leveraging them for infrastructure analysis across GCP and AWS.

This project provides an automated DevOps/SRE assistant that leverages:
1.  **Gemma 4 models** self-hosted via vLLM on Cloud TPUs.
2.  **Amazon Bedrock (Nova)** via the Agent Developer Kit (ADK).

It bridges cloud logging (GCP Cloud Logging / AWS CloudWatch) with private or managed inference endpoints to analyze infrastructure issues and suggest remediations.

## 🟢 Current Status: ONLINE
- **GCP Stack:** Gemma 4 inference stack is currently deployed and active on TPU v6e-8.
    *   **Active Endpoint:** `http://YOUR_TPU_IP_ADDRESS:8000`
- **AWS Stack:** Bedrock agents are ready for deployment via ADK.
    *   **Supported Models:** `amazon.nova-micro-v1:0`, `amazon.nova-lite-v1:0`

vLLM recipes
* https://github.com/AI-Hypercomputer/tpu-recipes/blob/main/inference/trillium/vLLM/Gemma4/README.md

vLLM github
* https://github.com/vllm-project/vllm/releases

never destroy the queued resource without explicit asking for it

## 🚀 Deployment Requirements

### 1. GCP Inference Stack (Gemma 4 on TPU)
*   **Hardware:** Cloud TPU v6e (Trillium) 
*   **Software:** `vllm/vllm-tpu:nightly`
*   **Model:** `google/gemma-4-31B-it`

### 2. AWS Managed Stack (Bedrock & Lightsail)
*   **Provider:** Amazon Bedrock (Model access enabled for Nova models).
*   **Deployment Target:** AWS Lightsail for Containers.
*   **Tools:** AWS CLI, Lightsail Control Plugin.
*   **Permissions:** `AmazonBedrockFullAccess`, `AmazonLightsailFullAccess`.

### 3. Software & API Dependencies
*   **Libraries:** `mcp`, `fastmcp`, `google-cloud-logging`, `google-adk`, `litellm`.
*   **Environment Variables:**
    *   `GOOGLE_CLOUD_PROJECT`: Your GCP Project ID.
    *   `AWS_REGION`: Your AWS Region (e.g., `us-east-1`).
    *   `BEDROCK_MODEL`: (Optional) Bedrock model ID.

## 🛠 Usage & Setup

### Step 1: Deploy Inference Stack
- **GCP:** Use `orchestrate_gemma4_stack` in the MCP server.
- **AWS:** Follow the guide in `agents/LIGHTSAIL.md` to deploy the Bedrock agent.

### Step 2: LiteLLM Proxy Setup
To enable seamless integration with the Gemini CLI for both TPU and Bedrock:

#### 1. Create `litellm_config.yaml`
```yaml
model_list:
  - model_name: "gemma4-tpu"
    litellm_params:
      model: "openai/google/gemma-4-31B-it"
      api_base: "http://YOUR_TPU_IP_ADDRESS:8000/v1"
      api_key: "none"

  - model_name: "bedrock-nova"
    litellm_params:
      model: "bedrock/amazon.nova-micro-v1:0"
      aws_region_name: "us-east-1"

    router_settings:
      model_group_alias:
        "gemini-2.0-flash": "gemma4-tpu"
        "gemini-2.0-flash-lite": "bedrock-nova" # Map flash-lite to Bedrock for efficiency
        "gemini-1.5-flash": "gemma4-tpu"
        "gemini-1.5-pro": "gemma4-tpu"
```

#### 2. Start the LiteLLM Proxy
```bash
litellm --config litellm_config.yaml --port 4000
```

#### 3. Configure Gemini CLI
```bash
export GOOGLE_GEMINI_BASE_URL="http://localhost:4000"
export GEMINI_MODEL="google/gemma-4-31B-it" # or "bedrock-nova"
export GEMINI_API_KEY="local-proxy-token"
```

## 🛠 Available Tools

The following tools are available via the MCP server:

### Infrastructure & Deployment
*   **`orchestrate_gemma4_stack`**: Seamlessly provisions a TPU Queued Resource and deploys the optimized vLLM stack.
*   **`get_vllm_deployment_config`**: Generates the exact `gcloud` command for manual TPU v6e deployment.
*   **`get_vllm_tpu_deployment_config`**: Generates GKE manifests for TPU-based deployments.
*   **`list_queued_resources`**: Lists all active and pending Queued Resources.
*   **`describe_queued_resource`**: Fetches detailed JSON status for a specific TPU resource.
*   **`check_tpu_availability`**: Simple check to see if a TPU resource is `ACTIVE`.
*   **`destroy_queued_resource`**: Safely deletes a TPU resource and its node.
*   **`manage_vllm_docker`**: Manages the vLLM Docker container on the TPU VM (`start`, `stop`, `restart`, `status`, `log`, and `rm` actions).

### Observability & Performance
*   **`get_system_status`**: Provides a high-level dashboard of TPU quota and vLLM health.
*   **`check_tpu_utilization`**: Monitors real-time HBM and Tensor Core pressure via Docker logs.
*   **`get_vllm_metrics`**: Fetches Prometheus metrics from the vLLM service.
*   **`fetch_queued_node_logs`**: Streams startup and container logs from the TPU node.
*   **`verify_model_health`**: Runs a deep logic check with latency reporting.
*   **`run_load_test_benchmark`**: Performs an external load test and reports throughput and latency (Avg/P95).
*   **`get_gemma4_full_report`**: Generates a comprehensive technical report of the entire stack.
*   **`validate_gemma4_deployment`**: Performs a comprehensive sanity check on the stack.

### AI & Interaction
*   **`query_queued_gemma4`**: Primary tool for interacting with the self-hosted model.
*   **`query_vllm_with_metrics`**: Provides streaming responses with TTFT and total latency data.
*   **`analyze_cloud_logging`**: Summarizes TPU-related errors using the self-hosted Gemma 4 model.
*   **`save_hf_token`**: Securely saves a Hugging Face API token to GCP Secret Manager.

## 🌟 Grand Demo
A standalone demo script is included to showcase the agent's capabilities:
```bash
python demo_launcher.py
```
