#!/bin/bash
# setup-fargate.sh - Provision AWS Fargate infrastructure for AI Course Creator

# Exit on error
set -e

# Configuration
AWS_REGION=${AWS_REGION:-"us-east-1"}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CLUSTER_NAME="adk-fargate-cluster"
SERVICE_NAME="adk-fargate-service"
TASK_FAMILY="adk-course-creator-task"
REPO_PREFIX="adk-course-creator"
EXECUTION_ROLE_NAME="ecsTaskExecutionRole-adk"

# Derived variables
ECR_LOGIN_SERVER="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "=== AWS Fargate Setup ==="
echo "Region: $AWS_REGION"
echo "Account: $AWS_ACCOUNT_ID"
echo "========================="

# 1. Create ECS Cluster
echo "Creating ECS Cluster: $CLUSTER_NAME..."
aws ecs create-cluster --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" > /dev/null

# 2. Create IAM Execution Role (if it doesn't exist)
echo "Ensuring IAM Execution Role exists..."
if ! aws iam get-role --role-name "$EXECUTION_ROLE_NAME" 2>/dev/null; then
    aws iam create-role --role-name "$EXECUTION_ROLE_NAME" \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": { "Service": "ecs-tasks.amazonaws.com" },
                    "Action": "sts:AssumeRole"
                }
            ]
        }' > /dev/null
    aws iam attach-role-policy --role-name "$EXECUTION_ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
    echo "Created $EXECUTION_ROLE_NAME"
fi

# 3. Create Security Group
echo "Setting up Security Group..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query 'Vpcs[0].VpcId' --output text)
SG_ID=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=adk-fargate-sg" --query 'SecurityGroups[0].GroupId' --output text)

if [ "$SG_ID" == "None" ] || [ -z "$SG_ID" ]; then
    SG_ID=$(aws ec2 create-security-group --group-name "adk-fargate-sg" --description "ADK Fargate Security Group" --vpc-id "$VPC_ID" --query 'GroupId' --output text)
    aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 8080 --cidr 0.0.0.0/0
    echo "Created Security Group: $SG_ID (allowed port 8080)"
fi

# 4. Register Task Definition
echo "Registering Task Definition..."
# We run all 5 containers in a single task for easy 'localhost' networking
TASK_DEF_JSON=$(cat <<EOF
{
  "family": "$TASK_FAMILY",
  "networkMode": "awsvpc",
  "executionRoleArn": "arn:aws:iam::$AWS_ACCOUNT_ID:role/$EXECUTION_ROLE_NAME",
  "containerDefinitions": [
    {
      "name": "app",
      "image": "$ECR_LOGIN_SERVER/$REPO_PREFIX-app:latest",
      "portMappings": [{ "containerPort": 8080, "hostPort": 8080 }],
      "essential": true,
      "environment": [
        { "name": "AGENT_SERVER_URL", "value": "http://localhost:8000" },
        { "name": "AGENT_NAME", "value": "orchestrator" }
      ]
    },
    {
      "name": "orchestrator",
      "image": "$ECR_LOGIN_SERVER/$REPO_PREFIX-orchestrator:latest",
      "portMappings": [{ "containerPort": 8000, "hostPort": 8000 }],
      "essential": true,
      "environment": [
        { "name": "RESEARCHER_AGENT_CARD_URL", "value": "http://localhost:8001/a2a/researcher/.well-known/agent-card.json" },
        { "name": "JUDGE_AGENT_CARD_URL", "value": "http://localhost:8002/a2a/judge/.well-known/agent-card.json" },
        { "name": "CONTENT_BUILDER_AGENT_CARD_URL", "value": "http://localhost:8003/a2a/content_builder/.well-known/agent-card.json" },
        { "name": "GOOGLE_API_KEY", "value": "$(cat $HOME/gemini.key 2>/dev/null)" }
      ]
    },
    {
      "name": "researcher",
      "image": "$ECR_LOGIN_SERVER/$REPO_PREFIX-researcher:latest",
      "portMappings": [{ "containerPort": 8001, "hostPort": 8001 }],
      "essential": true,
      "environment": [
        { "name": "GOOGLE_API_KEY", "value": "$(cat $HOME/gemini.key 2>/dev/null)" },
        { "name": "PORT", "value": "8001" }
      ]
    },
    {
      "name": "judge",
      "image": "$ECR_LOGIN_SERVER/$REPO_PREFIX-judge:latest",
      "portMappings": [{ "containerPort": 8002, "hostPort": 8002 }],
      "essential": true,
      "environment": [
        { "name": "GOOGLE_API_KEY", "value": "$(cat $HOME/gemini.key 2>/dev/null)" },
        { "name": "PORT", "value": "8002" }
      ]
    },
    {
      "name": "content-builder",
      "image": "$ECR_LOGIN_SERVER/$REPO_PREFIX-content-builder:latest",
      "portMappings": [{ "containerPort": 8003, "hostPort": 8003 }],
      "essential": true,
      "environment": [
        { "name": "GOOGLE_API_KEY", "value": "$(cat $HOME/gemini.key 2>/dev/null)" },
        { "name": "PORT", "value": "8003" }
      ]
    }
  ],
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "2048"
}
EOF
)

aws ecs register-task-definition --cli-input-json "$TASK_DEF_JSON" > /dev/null

# 5. Create ECS Service
echo "Creating ECS Service..."
SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text | tr '\t' ',')

aws ecs create-service \
    --cluster "$CLUSTER_NAME" \
    --service-name "$SERVICE_NAME" \
    --task-definition "$TASK_FAMILY" \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \
    --region "$AWS_REGION" > /dev/null

echo "Fargate Service created!"
echo "It may take a few minutes for the task to reach RUNNING state."
echo "Use 'make status' to check progress."
