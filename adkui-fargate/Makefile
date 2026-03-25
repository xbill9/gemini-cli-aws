export AWS_PAGER :=
# Makefile for ADK Comic Pipeline

.PHONY: clean test deploy run endpoint status fargate-status aws-destroy

clean:
	@echo "Cleaning up generated images and temporary files..."
	find . -name "*.log" -delete 2>/dev/null || true
	find images -name "*.png" -delete 2>/dev/null || true
	find output/images -name "*.png" -delete 2>/dev/null || true
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type d -name ".adk" -exec rm -rf {} +
	@echo "Clean completed."

deploy:
	./save-aws-creds.sh
	./deploy-fargate.sh

deploy-fargate:
	./deploy-fargate.sh

fargate-status:
	@aws ecs describe-services --cluster adk-fargate-cluster --services adk-fargate-service --region us-east-1 \
		--query 'services[0].{Name:serviceName, Status:status, Desired:desiredCount, Running:runningCount, TaskDef:taskDefinition}' \
		--output table

status:
	@aws ecs describe-services --cluster adk-fargate-cluster --services adk-fargate-service --region us-east-1 \
		--query 'services[0].{Name:serviceName, Status:status, Desired:desiredCount, Running:runningCount, TaskDef:taskDefinition}' \
		--output table

endpoint:
	@TASK_ARN=$$(aws ecs list-tasks --cluster adk-fargate-cluster --service-name adk-fargate-service --region us-east-1 --query 'taskArns[0]' --output text); \
	if [ "$$TASK_ARN" != "None" ] && [ -n "$$TASK_ARN" ]; then \
		ENI_ID=$$(aws ecs describe-tasks --cluster adk-fargate-cluster --tasks $$TASK_ARN --region us-east-1 --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text); \
		PUBLIC_IP=$$(aws ec2 describe-network-interfaces --network-interface-ids $$ENI_ID --region us-east-1 --query 'NetworkInterfaces[0].Association.PublicIp' --output text); \
		if [ "$$PUBLIC_IP" != "None" ] && [ -n "$$PUBLIC_IP" ]; then \
			echo "Fargate Endpoint: http://$$PUBLIC_IP:8080"; \
		else \
			echo "No public IP associated with the task."; \
		fi \
	else \
		echo "No running tasks found."; \
	fi

aws-destroy:
	@echo "Destroying AWS resources for adk-fargate..."
	@aws ecs update-service --cluster adk-fargate-cluster --service adk-fargate-service --desired-count 0 --region us-east-1 2>/dev/null || true
	@aws ecs delete-service --cluster adk-fargate-cluster --service adk-fargate-service --force --region us-east-1 2>/dev/null || true
	@aws ecs delete-cluster --cluster adk-fargate-cluster --region us-east-1 2>/dev/null || true
	@aws ecr delete-repository --repository-name adk-ui-image --region us-east-1 --force 2>/dev/null || true
	@echo "AWS resources destroyed."
