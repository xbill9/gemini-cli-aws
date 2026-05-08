# AWS Bedrock AgentCore Deployment Guide

This guide describes how to deploy your ADK agents to **Amazon Bedrock AgentCore**.

## 1. Prerequisites
- [AWS CLI installed and configured](https://aws.amazon.com/cli/)
- [AgentCore CLI installed](https://aws.amazon.com/bedrock/agentcore/)
- Python 3.14 (or compatible)

## 2. Configuration
The project is configured via `agentcore.json` in the root directory.

## 3. Local Development
You can test the agent locally using the AgentCore CLI:
```bash
agentcore dev --prompt "Hello"
```

## 4. Deployment
Deploy the infrastructure and agent to AWS:
```bash
agentcore deploy --yes
```

This will:
1. Package the agent code from the `agents/` directory.
2. Provision the necessary AWS resources (Runtime, IAM roles, etc.) via CDK.
3. Deploy the agent entrypoint `main_agentcore.py`.

## 5. Invocation
Once deployed, you can invoke your agent:
```bash
agentcore invoke "What models are available in Bedrock?"
```

You can also use the `agentcore status` command to get the deployed endpoint details.
