# Makefile for ADK Comic Pipeline

# Variables
CLUSTER_NAME = biometric-scout-cluster
SERVICE_NAME = biometric-scout-service
REGION = us-east-1

.PHONY: clean test deploy run status fargate-status endpoint

clean:
	@echo "Cleaning up generated images and temporary files..."
	find . -name "*.log" -delete 2>/dev/null || true
	find images -name "*.png" -delete 2>/dev/null || true
	find output/images -name "*.png" -delete 2>/dev/null || true
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type d -name ".adk" -exec rm -rf {} +
	@echo "Clean completed."

frontend:
	cd frontend && npm install && npm run build

mock:
	python mock/mock_server.py

deploy:
	./save-aws-creds.sh
	./deploy-fargate.sh

deploy-fargate:
	./deploy-fargate.sh

fargate-status:
	@echo "--- Fargate Cluster Status ---"
	@aws ecs describe-clusters --clusters $(CLUSTER_NAME) --region $(REGION) \
		--query 'clusters[0].{Name:clusterName, Status:status, Running:runningTasksCount, Pending:pendingTasksCount}' \
		--output table 2>/dev/null || echo "No Fargate cluster found."
	@echo "--- Fargate Service Status ---"
	@aws ecs describe-services --cluster $(CLUSTER_NAME) --services $(SERVICE_NAME) --region $(REGION) \
		--query 'services[0].{Service:serviceName, Status:status, Desired:desiredCount, Running:runningCount}' \
		--output table 2>/dev/null || echo "No Fargate service found."

endpoint:
	@echo "--- Fargate Endpoint ---"
	@TASK_ARN=$$(aws ecs list-tasks --cluster $(CLUSTER_NAME) --service $(SERVICE_NAME) --region $(REGION) --query 'taskArns[0]' --output text); \
	if [ "$$TASK_ARN" = "None" ] || [ -z "$$TASK_ARN" ]; then echo "No running tasks found."; exit 1; fi; \
	ENI_ID=$$(aws ecs describe-tasks --cluster $(CLUSTER_NAME) --tasks $$TASK_ARN --region $(REGION) --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text); \
	if [ "$$ENI_ID" = "None" ] || [ -z "$$ENI_ID" ]; then echo "No network interface found (task may be provisioning)."; exit 1; fi; \
	PUBLIC_IP=$$(aws ec2 describe-network-interfaces --network-interface-ids $$ENI_ID --region $(REGION) --query 'NetworkInterfaces[0].Association.PublicIp' --output text); \
	if [ "$$PUBLIC_IP" = "None" ] || [ -z "$$PUBLIC_IP" ]; then echo "No public IP assigned yet."; exit 1; fi; \
	echo "Application URL: http://$$PUBLIC_IP:8080"

status: fargate-status

