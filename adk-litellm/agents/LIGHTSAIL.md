# AWS Lightsail Deployment Guide

This guide describes how to deploy your ADK agents to **AWS Lightsail for Containers**.

## 1. Prerequisites
- [AWS CLI installed and configured](https://aws.amazon.com/cli/)
- [Docker installed](https://www.docker.com/get-started)
- [Lightsail Control Plugin installed](https://lightsail.aws.amazon.com/ls/docs/en_us/articles/amazon-lightsail-install-software)

## 2. Build and Test Locally
Build the image to ensure everything is correct:
```bash
docker build -t adk-bedrock-agent .
```

Run it locally to verify:
```bash
docker run -p 8080:8080 \
  -e AWS_ACCESS_KEY_ID=your_id \
  -e AWS_SECRET_ACCESS_KEY=your_key \
  -e AWS_REGION=us-east-1 \
  adk-bedrock-agent
```

## 3. Deploy to Lightsail

### A. Create the Container Service
If you haven't created the service yet:
```bash
aws lightsail create-container-service \
  --service-name bedrock-agent-service \
  --power micro \
  --scale 1
```

### B. Push the Image
Push your local image to the Lightsail service:
```bash
aws lightsail push-container-image \
  --service-name bedrock-agent-service \
  --image adk-bedrock-agent:latest \
  --label latest
```
*Note: The output will show a registered image name like `:bedrock-agent-service.latest.1`.*

### C. Create Deployment Configuration
Create a `deployment.json` file:
```json
{
  "containers": {
    "agent": {
      "image": ":bedrock-agent-service.latest.1",
      "ports": {
        "8080": "HTTP"
      },
      "environment": {
        "BEDROCK_MODEL": "bedrock/amazon.nova-micro-v1:0",
        "AWS_REGION": "us-east-1",
        "AWS_ACCESS_KEY_ID": "YOUR_KEY",
        "AWS_SECRET_ACCESS_KEY": "YOUR_SECRET"
      }
    }
  },
  "publicEndpoint": {
    "containerName": "agent",
    "containerPort": 8080
  }
}
```

Apply the deployment:
```bash
aws lightsail create-container-service-deployment \
  --service-name bedrock-agent-service \
  --cli-input-json file://deployment.json
```

## 4. Accessing your Agent
Once deployed, Lightsail will provide a public URL like:
`https://bedrock-agent-service.xxxxxx.us-east-1.apps.amazonlightsail.com`

You can access the **ADK Web UI** directly at this URL or interact via API at `/run_sse`.
