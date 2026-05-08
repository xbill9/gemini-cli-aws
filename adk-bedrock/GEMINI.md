# Gemini Code Assistant Context

This document provides context for the Gemini Code Assistant to understand the project and assist in development. It contains information relevant to the Gemini CLI's operation and interaction with this project, including specific setup instructions for integrating with the CLI.

## Role
This project functions as an expert AWS SRE/DevOps Engineer, specialized in **Amazon Bedrock** and the **Agent Developer Kit (ADK)**. Its primary goal is to manage managed cloud AI services (Bedrock), leveraging them for infrastructure analysis across AWS.

This project provides an automated DevOps/SRE assistant that leverages **Amazon Bedrock (Nova)** via the Agent Developer Kit (ADK).

## 🟢 Current Status: ONLINE (AWS PRIMARY)
- **AWS Stack:** Bedrock agents are deployed and managed via **Amazon Bedrock AgentCore**.
    *   **Active Platform:** Bedrock AgentCore
    *   **Supported Models:** `amazon.nova-micro-v1:0`, `amazon.nova-lite-v1:0`

## 🚀 Deployment Requirements

### 1. AWS Managed Stack (Bedrock & AgentCore)
*   **Provider:** Amazon Bedrock (Model access enabled for Nova models).
*   **Deployment Target:** Amazon Bedrock AgentCore.
*   **Tools:** AWS CLI, AgentCore CLI.
*   **Permissions:** `AmazonBedrockFullAccess`, `AdministratorAccess` (for CDK/AgentCore).

### 2. Software & API Dependencies
*   **Libraries:** `bedrock-agentcore`, `strands-agents`, `google-adk`, `litellm`.
*   **Environment Variables:**
    *   `AWS_REGION`: Your AWS Region (e.g., `us-east-1`).
    *   `BEDROCK_MODEL`: (Optional) Bedrock model ID.

## 🛠 Usage & Setup

### Step 1: Deploy Bedrock Agent
- **AWS:** Use the Bedrock AgentCore CLI to deploy the agent:
```bash
cd agentcore
agentcore deploy --yes
```

### Step 2: Access the Agent
Once deployed, the agent is exposed via a public HTTP Gateway URL. You can find this URL using:
```bash
agentcore status --json
```

## 🛠 Available Tools

The agent is designed to interact with AWS services via Bedrock and can be extended with custom tools using the ADK.

## 🌟 Grand Demo
A standalone demo script is included to showcase the agent's capabilities:
```bash
python demo_launcher.py
```
