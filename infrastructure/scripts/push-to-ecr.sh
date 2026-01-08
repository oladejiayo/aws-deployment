#!/bin/bash
# push-to-ecr.sh - Script to build and push Docker images to ECR

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get AWS account ID and region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${AWS_REGION:-us-east-1}
PROJECT_NAME=${PROJECT_NAME:-aws-demo}

echo -e "${YELLOW}AWS Account: $AWS_ACCOUNT_ID${NC}"
echo -e "${YELLOW}AWS Region: $AWS_REGION${NC}"
echo -e "${YELLOW}Project: $PROJECT_NAME${NC}"

# Login to ECR
echo -e "${GREEN}Logging into ECR...${NC}"
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and push backend
echo -e "${GREEN}Building backend image...${NC}"
docker build -t $PROJECT_NAME-backend ../backend

echo -e "${GREEN}Tagging backend image...${NC}"
docker tag $PROJECT_NAME-backend:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME-backend:latest

echo -e "${GREEN}Pushing backend image...${NC}"
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME-backend:latest

# Build and push frontend
echo -e "${GREEN}Building frontend image...${NC}"
docker build -t $PROJECT_NAME-frontend ../frontend

echo -e "${GREEN}Tagging frontend image...${NC}"
docker tag $PROJECT_NAME-frontend:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME-frontend:latest

echo -e "${GREEN}Pushing frontend image...${NC}"
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME-frontend:latest

echo -e "${GREEN}Done! Images pushed to ECR:${NC}"
echo "  - $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME-backend:latest"
echo "  - $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME-frontend:latest"
