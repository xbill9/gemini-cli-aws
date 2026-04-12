#!/bin/bash

# ==============================================================================
# Verify Setup Script - Biometric Scout (AWS Fargate)
# 
# Checks that the environment is correctly configured:
# 1. AWS CLI is installed and configured
# 2. Python dependencies are installed
# 3. .env configuration exists
# ==============================================================================

# --- Colors for Output ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}🚀 Verifying Biometric Scout Infrastructure...${NC}\n"

ALL_PASSED=true

# ------------------------------------------------------------------------------
# 1. Check AWS CLI
# ------------------------------------------------------------------------------
if command -v aws &> /dev/null; then
    echo -e "✅ AWS CLI: ${GREEN}Installed${NC}"
    # Check if configured (at least one profile or env var)
    if aws sts get-caller-identity &> /dev/null; then
        echo -e "✅ AWS Credentials: ${GREEN}Active${NC}"
    else
        echo -e "⚠️  AWS Credentials: ${YELLOW}Not Found or Invalid${NC}"
        echo "   Run: aws configure"
        # Not failing hard here as they might use .aws_creds file
    fi
else
    echo -e "❌ AWS CLI: ${RED}Not Found${NC}"
    echo "   Please install the AWS CLI: https://aws.amazon.com/cli/"
    ALL_PASSED=false
fi

# ------------------------------------------------------------------------------
# 2. Check Python Dependencies
# ------------------------------------------------------------------------------
# Format: "PipPackageName:PythonImportName"
DEPS=(
    "fastapi:fastapi"
    "uvicorn:uvicorn"
    "google-genai:google.genai"
    "websockets:websockets"
    "python-dotenv:dotenv"
    "google-adk:google.adk"
)

MISSING_DEPS=()

for DEP in "${DEPS[@]}"; do
    PKG_NAME="${DEP%%:*}"    # String before colon
    IMPORT_NAME="${DEP##*:}" # String after colon
    
    # Try to import the module silently
    python3 -c "import $IMPORT_NAME" 2>/dev/null
    
    if [ $? -ne 0 ]; then
        MISSING_DEPS+=("$PKG_NAME")
    fi
done

if [ ${#MISSING_DEPS[@]} -eq 0 ]; then
    echo -e "✅ Python Environment: ${GREEN}Ready${NC}"
else
    echo -e "❌ Python Dependencies: ${RED}Missing ${MISSING_DEPS[*]}${NC}"
    echo "   Run: pip install -r requirements.txt"
    ALL_PASSED=false
fi

# ------------------------------------------------------------------------------
# 3. Check .env File
# ------------------------------------------------------------------------------
if [ -f ".env" ]; then
    echo -e "✅ .env Configuration: ${GREEN}Found${NC}"
else
    echo -e "❌ .env Configuration: ${RED}Missing${NC}"
    echo "   Run: ./init.sh"
    ALL_PASSED=false
fi

# ------------------------------------------------------------------------------
# Final Summary
# ------------------------------------------------------------------------------
echo -e "\n-------------------------------------------------------"
if [ "$ALL_PASSED" = true ]; then
    echo -e "🎉 ${GREEN}${BOLD}SYSTEMS ONLINE. READY FOR MISSION.${NC}"
else
    echo -e "🛑 ${RED}${BOLD}SYSTEM CHECKS FAILED.${NC} Please resolve the issues above."
fi
