export AWS_PAGER :=

# Makefile for Biometric Security System

.PHONY: clean test lint deploy run endpoint frontend mock adk deploy-lightsail lightsail-status status aws-destroy

clean:
	@echo "Cleaning up logs, caches, and temporary files..."
	find . -type f -name "*.log" -delete 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".adk" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".ruff_cache" -exec rm -rf {} + 2>/dev/null || true
	rm -rf frontend/dist 2>/dev/null || true
	@echo "Clean completed."

test:
	python -m pytest

lint:
	ruff check .
	ruff format --check .
	cd frontend && npm run lint

frontend:
	cd frontend && npm install && npm run build

endpoint:
	@aws lightsail get-container-services --service-name biometric-scout-service --region us-east-1 \
                --query 'containerServices[0].url' \
                --output text

deploy:
	./save-aws-creds.sh
	./deploy-lightsail.sh

deploy-lightsail:
	./deploy-lightsail.sh

lightsail-status:
	@aws lightsail get-container-services --service-name biometric-scout-service --region us-east-1 \
		--query 'containerServices[0].{State:state, Deployment:currentDeployment.state, URL:publicEndpoint.url}' \
		--output table

status:
	@aws lightsail get-container-services --service-name biometric-scout-service --region us-east-1 \
		--query 'containerServices[0].{State:state, Deployment:currentDeployment.state, URL:publicEndpoint.url}' \
		--output table

aws-destroy:
	@echo "Destroying AWS resources for gemini31-lightsail..."
	@aws lightsail delete-container-service --service-name biometric-scout-service --region us-east-1 2>/dev/null || true
	@echo "AWS resources destroyed."

run:
	. ./biosync.sh

mock:
	. ./mock.sh

adk:
	. ./runadk.sh

testadk:
	. ./testadk.sh
