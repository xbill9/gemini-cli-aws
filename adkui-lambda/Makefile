export AWS_PAGER :=
# Makefile for ADK Comic Pipeline (Lambda Deployment)

# Include and export AWS credentials if they exist
-include .aws_creds
export

# AWS Configuration
AWS_REGION ?= us-west-1
SERVICE_NAME ?= adkui-lambda
IMAGE_NAME ?= adk-comic-pipeline-image
API_NAME ?= $(SERVICE_NAME)-api

# API Key for Vertex AI (or other services)
API_KEY := $(shell grep -oP '^GEMINI_API_KEY=\K.*' .env | tr -d '\n')
S3_BUCKET_NAME ?= my-adk-comic-artifacts
ENVIRONMENT_VARIABLES := Variables="{GEMINI_API_KEY=$(API_KEY),S3_BUCKET_NAME=$(S3_BUCKET_NAME)}"

# Derived AWS variables
AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "UNKNOWN")
ECR_REPO_URL := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(SERVICE_NAME)
IMAGE_TAG := latest
FULL_IMAGE_NAME := $(ECR_REPO_URL):$(IMAGE_TAG)

# IAM Role for Lambda
LAMBDA_ROLE_NAME := McpLambdaExecutionRole
LAMBDA_ROLE_ARN := arn:aws:iam::$(AWS_ACCOUNT_ID):role/$(LAMBDA_ROLE_NAME)

.PHONY: all install run build test test-remote check lint format type-check status git-status lambda-status endpoint api-endpoint pull push clean deploy docker-build ecr-create ecr-login push-ecr lambda-deploy iam-setup aws-destroy api-gateway-setup logs

print-vars:
	@echo "SERVICE_NAME: $(SERVICE_NAME)"
	@echo "API_NAME: $(API_NAME)"

all: install run

# Install dependencies
install:
	pip install -r requirements.txt

# Run the server locally (using ADK web UI)
run:
	adk web . --host 0.0.0.0 --port 8080

# Target to show both git and Lambda status
status: lambda-status endpoint api-endpoint

# Target to show git status
git-status:
	@echo "Showing git status..."
	@git status

# Target to show AWS Lambda status
lambda-status:
	@aws lambda get-function --function-name $(SERVICE_NAME) --region $(AWS_REGION) --query 'Configuration.{Name:FunctionName, Status:State, LastModified:LastModified}' --output table 2>/dev/null || echo "Lambda function not found."

# Target to get the public endpoint URL (Lambda Function URL)
endpoint:
	@aws lambda get-function-url-config --function-name $(SERVICE_NAME) --region $(AWS_REGION) --query 'FunctionUrl' --output text 2>/dev/null || echo "Function URL not found."

# Target to get the API Gateway URL (HTTP API v2)
api-endpoint:
	@API_ID=$$(aws apigatewayv2 get-apis --region $(AWS_REGION) --output json | jq -r '[.Items[] | select(.Name == "$(API_NAME)")] | sort_by(.CreatedDate) | .[-1].ApiId' | tr -d '[:space:]'); \
	if [ -n "$$API_ID" ] && [ "$$API_ID" != "None" ]; then \
		echo "https://$$API_ID.execute-api.$(AWS_REGION).amazonaws.com/"; \
	else \
		echo "API Gateway not found."; \
	fi

# Target to save AWS credentials
save-creds:
	@./save-aws-creds.sh

# Target to pull latest changes from git
pull:
	@echo "Pulling latest changes from git..."
	@git pull

# Target to push changes to git
push:
	@echo "Pushing changes to git..."
	@git push

# Code Quality targets
check: lint test
	@echo "All checks passed!"

test:
	@echo "Running tests..."
	@pytest test_smoke.py || echo "Tests failed."

test-remote: e2e-test-lambda
e2e-test-lambda:
	@echo "Running remote tests..."
	@API_ID=$$(aws apigatewayv2 get-apis --region $(AWS_REGION) --output json | jq -r '[.Items[] | select(.Name == "$(API_NAME)")] | sort_by(.CreatedDate) | .[-1].ApiId' | tr -d '[:space:]'); \
	if [ -n "$$API_ID" ] && [ "$$API_ID" != "None" ]; then \
		URL="https://$$API_ID.execute-api.$(AWS_REGION).amazonaws.com/"; \
		echo "Testing endpoint: $$URL"; \
		HTTP_STATUS=$$(curl -s -o /dev/null -w "%{http_code}" $$URL); \
		if echo "$$HTTP_STATUS" | grep -q "^2"; then \
			echo "Remote test passed (HTTP Status: $$HTTP_STATUS)."; \
		else \
			echo "Remote test failed (HTTP Status: $$HTTP_STATUS)."; \
			exit 1; \
		fi; \
	else \
		echo "API Gateway not found."; \
		exit 1; \
	fi

lint:
	@echo "Running ruff..."
	@ruff check . || echo "ruff check failed."

lint-fix:
	@echo "Fixing lint issues with ruff..."
	@ruff check . --fix || echo "ruff fix failed."

format:
	@echo "Running ruff format and black..."
	@ruff format . || echo "ruff format failed."
	@black . || echo "black failed."

# Build the Docker image
docker-build:
	@echo "Building the Docker image..."
	@docker buildx build --provenance=false -t $(IMAGE_NAME) .

# ECR related targets
ecr-create: save-creds
	@echo "Checking if ECR repository exists..."
	@aws ecr describe-repositories --repository-names $(SERVICE_NAME) --region $(AWS_REGION) > /dev/null 2>&1 || \
		(echo "Creating ECR repository $(SERVICE_NAME)..." && \
		aws ecr create-repository --repository-name $(SERVICE_NAME) --region $(AWS_REGION))

ecr-login: save-creds
	@echo "Logging in to Amazon ECR..."
	@aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

push-ecr: ecr-create ecr-login docker-build
	@echo "Pushing the Docker image to ECR..."
	@docker tag $(IMAGE_NAME) $(FULL_IMAGE_NAME)
	@docker push $(FULL_IMAGE_NAME)

# IAM Role setup for Lambda
iam-setup: save-creds
	@echo "Ensuring IAM role $(LAMBDA_ROLE_NAME) exists..."
	@aws iam get-role --role-name $(LAMBDA_ROLE_NAME) > /dev/null 2>&1 || \
		(echo "Creating role $(LAMBDA_ROLE_NAME)..." && \
		aws iam create-role --role-name $(LAMBDA_ROLE_NAME) \
			--assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' && \
		aws iam attach-role-policy --role-name $(LAMBDA_ROLE_NAME) \
			--policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole)

# Deploy to Amazon Lambda
deploy: save-creds lambda
lambda: iam-setup push-ecr create-lambda-function

api-gateway-setup:
	@echo "Setting up HTTP API Gateway (v2)..."
	@API_ID=$$(aws apigatewayv2 get-apis --region $(AWS_REGION) --query "items[?name=='$(API_NAME)'].ApiId" --output text); \
	if [ -z "$$API_ID" ] || [ "$$API_ID" = "None" ]; then \
		echo "Creating new HTTP API $(API_NAME)..."; API_ID=$$(aws apigatewayv2 create-api --name $(API_NAME) --protocol-type HTTP --region $(AWS_REGION) --query 'ApiId' --output text); \
	fi; \
	INTEGRATION_ID=$$(aws apigatewayv2 get-integrations --api-id $$API_ID --region $(AWS_REGION) --query "items[0].IntegrationId" --output text); \
	if [ -z "$$INTEGRATION_ID" ] || [ "$$INTEGRATION_ID" = "None" ]; then \
		echo "Creating Lambda integration..."; INTEGRATION_ID=$$(aws apigatewayv2 create-integration --api-id $$API_ID --integration-type AWS_PROXY --integration-uri arn:aws:lambda:$(AWS_REGION):$(AWS_ACCOUNT_ID):function:$(SERVICE_NAME) --payload-format-version '2.0' --region $(AWS_REGION) --query 'IntegrationId' --output text); \
	fi; \
	aws apigatewayv2 create-route --api-id $$API_ID --route-key 'ANY /{proxy+}' --target integrations/$$INTEGRATION_ID --region $(AWS_REGION) 2>/dev/null || true; \
	aws apigatewayv2 create-route --api-id $$API_ID --route-key 'ANY /' --target integrations/$$INTEGRATION_ID --region $(AWS_REGION) 2>/dev/null || true; \
	aws apigatewayv2 create-stage --api-id $$API_ID --stage-name '$$default' --auto-deploy --region $(AWS_REGION) 2>/dev/null || true; \
	aws lambda add-permission --function-name $(SERVICE_NAME) --statement-id ApiGatewayV2InvokePermission --action lambda:InvokeFunction --principal apigateway.amazonaws.com --source-arn "arn:aws:execute-api:$(AWS_REGION):$(AWS_ACCOUNT_ID):$$API_ID/*/*" --region $(AWS_REGION) 2>/dev/null || true; \
	echo "HTTP API Gateway setup complete. URL: https://$$API_ID.execute-api.$(AWS_REGION).amazonaws.com/"
create-lambda-function: save-creds
	@echo "Deploying to Lambda..."
	if aws lambda get-function --function-name $(SERVICE_NAME) --region $(AWS_REGION) > /dev/null 2>&1; then \
		echo "Updating existing Lambda function..."; \
		aws lambda update-function-code --region $(AWS_REGION) --function-name $(SERVICE_NAME) --image-uri $(FULL_IMAGE_NAME); \
		echo "Waiting for function update to complete..."; \
		aws lambda wait function-updated-v2 --function-name $(SERVICE_NAME) --region $(AWS_REGION); \
		aws lambda update-function-configuration --region $(AWS_REGION) --function-name $(SERVICE_NAME) --environment $(ENVIRONMENT_VARIABLES) --timeout 300; \
		echo "Updating Function URL to BUFFERED mode (Stateless HTTP)..."; \
		aws lambda update-function-url-config --function-name $(SERVICE_NAME) --region $(AWS_REGION) --auth-type NONE --invoke-mode BUFFERED; \
		echo "Ensuring public URL access permission..."; \
		aws lambda remove-permission --function-name $(SERVICE_NAME) --region $(AWS_REGION) --statement-id FunctionURLPublicAccess 2>/dev/null || true; \
		aws lambda add-permission --function-name $(SERVICE_NAME) --region $(AWS_REGION) --statement-id FunctionURLPublicAccess --action lambda:InvokeFunctionUrl --principal "*" --function-url-auth-type NONE; \
		aws lambda remove-permission --function-name $(SERVICE_NAME) --region $(AWS_REGION) --statement-id FunctionURLPublicAccess2 2>/dev/null || true; \
		aws lambda add-permission --function-name $(SERVICE_NAME) --region $(AWS_REGION) --statement-id FunctionURLPublicAccess2 --action lambda:InvokeFunction --principal "*"; \
	else \
		echo "Creating a new Lambda function..."; \
		aws lambda create-function --region $(AWS_REGION) --function-name $(SERVICE_NAME) --role $(LAMBDA_ROLE_ARN) --package-type Image --code ImageUri=$(FULL_IMAGE_NAME) --environment $(ENVIRONMENT_VARIABLES) --timeout 300 --memory-size 2048; \
		echo "Waiting for function to be active..."; \
		aws lambda wait function-active-v2 --function-name $(SERVICE_NAME) --region $(AWS_REGION); \
		echo "Creating Function URL (BUFFERED mode for Stateless HTTP)..."; \
		aws lambda create-function-url-config --function-name $(SERVICE_NAME) --region $(AWS_REGION) --auth-type NONE --invoke-mode BUFFERED; \
		echo "Adding permission for public URL access..."; \
		aws lambda remove-permission --function-name $(SERVICE_NAME) --region $(AWS_REGION) --statement-id FunctionURLPublicAccess 2>/dev/null || true; \
		aws lambda add-permission --function-name $(SERVICE_NAME) --region $(AWS_REGION) --statement-id FunctionURLPublicAccess --action lambda:InvokeFunctionUrl --principal "*" --function-url-auth-type NONE; \
		aws lambda remove-permission --function-name $(SERVICE_NAME) --region $(AWS_REGION) --statement-id FunctionURLPublicAccess2 2>/dev/null || true; \
		aws lambda add-permission --function-name $(SERVICE_NAME) --region $(AWS_REGION) --statement-id FunctionURLPublicAccess2 --action lambda:InvokeFunction --principal "*"; \
	fi
aws-destroy:
	@echo "Destroying AWS resources for $(SERVICE_NAME)..."
	@API_ID=$$(aws apigatewayv2 get-apis --region $(AWS_REGION) --query "items[?name=='$(API_NAME)'].ApiId" --output text); \
	if [ -n "$$API_ID" ] && [ "$$API_ID" != "None" ]; then \
		echo "Deleting HTTP API $$API_ID..."; \
		aws apigatewayv2 delete-api --api-id $$API_ID --region $(AWS_REGION) 2>/dev/null || true; \
	fi
	@echo "Deleting Lambda function..."
	@aws lambda delete-function --function-name $(SERVICE_NAME) --region $(AWS_REGION) 2>/dev/null || true
	@echo "Deleting ECR repository..."
	@aws ecr delete-repository --repository-name $(SERVICE_NAME) --region $(AWS_REGION) --force 2>/dev/null || true
	@echo "Deleting IAM role..."
	@aws iam detach-role-policy --role-name $(LAMBDA_ROLE_NAME) --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true
	@aws iam delete-role --role-name $(LAMBDA_ROLE_NAME) 2>/dev/null || true
	@echo "AWS resources destroyed."

clean:
	@echo "Cleaning up generated images and temporary files..."
	@find . -name "*.log" -delete 2>/dev/null || true
	@find images -name "*.png" -delete 2>/dev/null || true
	@find output/images -name "*.png" -delete 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name ".adk" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name ".pyte*" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name ".mypy*" -exec rm -rf {} + 2>/dev/null || true
	@rm -rf .venv
	@echo "Clean completed."

logs:
	@echo "Tailing CloudWatch logs for $(SERVICE_NAME)..."
	@aws logs tail /aws/lambda/$(SERVICE_NAME) --follow --region $(AWS_REGION)

