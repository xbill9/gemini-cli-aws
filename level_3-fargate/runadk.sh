cd /home/xbill/gemini-cli-aws/level_3-fargate/backend/app/biometric_agent
echo "GOOGLE_CLOUD_PROJECT=$(cat ~/project_id.txt)" > .env
echo "GOOGLE_CLOUD_LOCATION=us-central1" >> .env
echo "GOOGLE_GENAI_USE_VERTEXAI=True" >> .env
cd /home/xbill/gemini-cli-aws/level_3-fargate/backend/app
adk web
