# Multi-Cloud DevOps Agent (MCP & ADK)

## Role
This project functions as an expert TPU and AWS SRE/DevOps Engineer, specialized in the **Gemma 4** ecosystem and **Amazon Bedrock**. Its primary goal is to manage self-hosted and managed inference stacks and leverage them for infrastructure analysis.

This project provides an automated DevOps/SRE assistant that leverages:
1.  **Gemma 4 models** self-hosted via vLLM on Cloud TPUs.
2.  **Amazon Bedrock (Nova)** via the Agent Developer Kit (ADK).

It bridges Google Cloud Logging and AWS CloudWatch with inference endpoints to analyze infrastructure issues and suggest remediations.

## 🟢 Current Status: ONLINE
- **GCP Stack:** The Gemma 4 inference stack is currently deployed and active on TPU v6e-8.
    *   **Active Endpoint:** `http://YOUR_TPU_IP_ADDRESS:8000`
- **AWS Stack:** Bedrock agents are ready for deployment using the Nova model series.

## 🚀 Deployment Options

### 1. GCP Inference Stack (The Inference Stack)
The MCP server expects a running vLLM instance. Your TPU deployment for the model needs:
*   **Hardware:** Cloud TPU v6e (Trillium) with topology `2x4` (8 chips).
*   **Software:** `vllm/vllm-tpu:nightly` specialized container.
*   **Model:** `google/gemma-4-31B-it` (Hugging Face ID).
*   **Runtime:** `v2-alpha-tpuv6e` for Flex-start / Queued Resources.

### 2. AWS Managed Stack (ADK on Lightsail)
For a low-latency, managed experience on AWS:
*   **Model:** `amazon.nova-micro-v1:0` via Bedrock.
*   **Deployment:** AWS Lightsail for Containers.
*   **Guide:** See [agents/LIGHTSAIL.md](agents/LIGHTSAIL.md) for step-by-step instructions.

## 🛠 Usage & Setup

### Step 1: Infrastructure Deployment
- **GCP TPU:** Use the `orchestrate_gemma4_stack` tool within the MCP server.
- **AWS Bedrock:** Use the ADK to deploy to Lightsail (see `agents/LIGHTSAIL.md`).

### Step 2: Run the MCP Server
Install dependencies and run the server locally:
```bash
make install
make run
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