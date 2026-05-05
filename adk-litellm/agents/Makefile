# AWS Lightsail Deployment Makefile

SERVICE_NAME=bedrock-agent-service
IMAGE_NAME=adk-bedrock-agent
REGION=us-east-1

.PHONY: build push deploy-config deploy status

build:
	docker build -t $(IMAGE_NAME) .

push: build
	aws lightsail push-container-image \
		--service-name $(SERVICE_NAME) \
		--image $(IMAGE_NAME):latest \
		--label latest

deploy-config:
	@echo "Creating deployment.json..."
	@IMAGE_ID=$$(aws lightsail get-container-images --service-name $(SERVICE_NAME) | grep -o '":$(SERVICE_NAME).latest.[0-9]*"' | head -1 | tr -d '":'); \
	echo "Using Image ID: $$IMAGE_ID"; \
	echo "{\c" > deployment.json; \
	echo "  \"containers\": {\c" >> deployment.json; \
	echo "    \"agent\": {\c" >> deployment.json; \
	echo "      \"image\": \":$$IMAGE_ID\",\c" >> deployment.json; \
	echo "      \"ports\": {\c" >> deployment.json; \
	echo "        \"8080\": \"HTTP\"\c" >> deployment.json; \
	echo "      },\c" >> deployment.json; \
	echo "      \"environment\": {\c" >> deployment.json; \
	echo "        \"BEDROCK_MODEL\": \"bedrock/amazon.nova-micro-v1:0\",\c" >> deployment.json; \
	echo "        \"AWS_REGION\": \"$(REGION)\",\c" >> deployment.json; \
	echo "        \"AWS_ACCESS_KEY_ID\": \"$$AWS_ACCESS_KEY_ID\",\c" >> deployment.json; \
	echo "        \"AWS_SECRET_ACCESS_KEY\": \"$$AWS_SECRET_ACCESS_KEY\"\c" >> deployment.json; \
	echo "      }\c" >> deployment.json; \
	echo "    }\c" >> deployment.json; \
	echo "  },\c" >> deployment.json; \
	echo "  \"publicEndpoint\": {\c" >> deployment.json; \
	echo "    \"containerName\": \"agent\",\c" >> deployment.json; \
	echo "    \"containerPort\": 8080\c" >> deployment.json; \
	echo "  }\c" >> deployment.json; \
	echo "}" >> deployment.json

deploy: push deploy-config
	aws lightsail create-container-service-deployment \
		--service-name $(SERVICE_NAME) \
		--cli-input-json file://deployment.json

status:
	aws lightsail get-container-services --service-name $(SERVICE_NAME)
