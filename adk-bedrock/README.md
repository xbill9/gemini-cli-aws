# Bedrock ADK Agent

## Role
This project functions as an expert AWS SRE/DevOps Engineer, specialized in **Amazon Bedrock** and the **Agent Developer Kit (ADK)**. Its primary goal is to manage managed cloud AI services (Bedrock) and leverage them for infrastructure analysis.

This project provides an automated DevOps/SRE assistant that leverages **Amazon Bedrock (Nova)** via the Agent Developer Kit (ADK).

## 🟢 Current Status: ONLINE
- **AWS Stack:** Bedrock agents are deployed and managed via **Amazon Bedrock AgentCore**.
    *   **Active Platform:** Bedrock AgentCore
    *   **Supported Models:** `amazon.nova-micro-v1:0`, `amazon.nova-lite-v1:0`

## 🚀 Deployment

### AWS Managed Stack (Bedrock & AgentCore)
For a managed experience on AWS:
*   **Model:** `amazon.nova-micro-v1:0` via Bedrock.
*   **Deployment:** Amazon Bedrock AgentCore.

To deploy:
```bash
cd agentcore
agentcore deploy --yes
```

## 🛠 Usage & Setup

### Step 1: Deploy the Agent
Use the Bedrock AgentCore CLI to deploy the agent to AWS.

### Step 2: Access the Agent
Once deployed, the agent is exposed via a public HTTP Gateway URL. You can retrieve the URL using:
```bash
agentcore status --json
```

## 🌟 Grand Demo
A standalone demo script is included to showcase the agent's capabilities:
```bash
python demo_launcher.py
```
