# AWS App Runner Deployment Guide

## Overview

This option deploys the application using AWS App Runner:
- **Backend**: App Runner service from ECR image
- **Frontend**: App Runner service from ECR image OR S3 + CloudFront
- **Database**: RDS PostgreSQL with VPC Connector

## Architecture

### High-Level Overview
```
                    ┌─────────────────┐
                    │   Internet      │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   │                   ▼
┌─────────────────┐          │          ┌─────────────────┐
│  App Runner     │          │          │  App Runner     │
│  (Frontend)     │          │          │  (Backend)      │
│  Auto HTTPS     │          │          │  Auto HTTPS     │
└─────────────────┘          │          └────────┬────────┘
                             │                   │
                             │          ┌────────▼────────┐
                             │          │  VPC Connector  │
                             │          └────────┬────────┘
                             │                   │
                             │          ┌────────▼────────┐
                             └─────────►│  RDS PostgreSQL │
                                        │ (Private Subnet)│
                                        └─────────────────┘
```

### Detailed Architecture with App Runner Services
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                               Internet Users                                 │
└──────────────────┬───────────────────────────────────┬──────────────────────┘
                   │                                   │
                   │ (Frontend)                        │ (API Requests)
                   │                                   │
┌──────────────────▼──────────────┐   ┌───────────────▼──────────────────────┐
│   AWS App Runner Service        │   │   AWS App Runner Service             │
│   Name: aws-demo-frontend       │   │   Name: aws-demo-backend             │
│                                 │   │                                      │
│ ┌─────────────────────────────┐ │   │ ┌──────────────────────────────────┐ │
│ │ Auto-Generated URL:         │ │   │ │ Auto-Generated URL:              │ │
│ │ https://xxxxx.awsapprunner  │ │   │ │ https://yyyyy.awsapprunner       │ │
│ │           .com              │ │   │ │           .com                   │ │
│ └─────────────────────────────┘ │   │ └──────────────────────────────────┘ │
│                                 │   │                                      │
│ Configuration:                  │   │ Configuration:                       │
│ • Source: ECR Image             │   │ • Source: ECR Image                  │
│ • Port: 80                      │   │ • Port: 8080                         │
│ • CPU: 0.25 vCPU                │   │ • CPU: 0.25 vCPU                     │
│ • Memory: 0.5 GB                │   │ • Memory: 0.5 GB                     │
│ • Auto Scaling: 1-10 instances  │   │ • Auto Scaling: 1-10 instances       │
│ • Health Check: / (HTTP 200)    │   │ • Health Check: /api/messages        │
│                                 │   │                                      │
│ ┌─────────────────────────────┐ │   │ Environment Variables:               │
│ │   Container Instances       │ │   │ • DATABASE_URL=jdbc:postgresql://... │
│ │   (Managed by App Runner)   │ │   │ • DATABASE_USER=postgres             │
│ │                             │ │   │ • DATABASE_PASSWORD=***              │
│ │  ┌──────┐  ┌──────┐        │ │   │                                      │
│ │  │Nginx │  │Nginx │  ...   │ │   │ ┌──────────────────────────────────┐ │
│ │  │:80   │  │:80   │        │ │   │ │   VPC Connector                  │ │
│ │  │React │  │React │        │ │   │ │   (Enables private VPC access)   │ │
│ │  └──────┘  └──────┘        │ │   │ │                                  │ │
│ └─────────────────────────────┘ │   │ │ • Subnets: 10.0.1.0/24,          │ │
│                                 │   │ │            10.0.2.0/24           │ │
│ Features:                       │   │ │ • Security Group: app-runner-sg  │ │
│ ✓ Automatic HTTPS               │   │ └──────────────┬───────────────────┘ │
│ ✓ Auto Scaling (request-based) │   │                │                     │
│ ✓ Zero downtime deployments     │   │ ┌──────────────▼───────────────────┐ │
│ ✓ Built-in load balancing       │   │ │   Container Instances            │ │
│ ✓ Managed runtime updates       │   │ │   (Managed by App Runner)        │ │
│                                 │   │ │                                  │ │
└─────────────────────────────────┘   │ │  ┌─────────┐  ┌─────────┐       │ │
                                      │ │  │Spring   │  │Spring   │  ...  │ │
                                      │ │  │Boot:8080│  │Boot:8080│       │ │
                                      │ │  └─────────┘  └─────────┘       │ │
                                      │ └──────────────┬───────────────────┘ │
                                      │                │                     │
                                      │                │ (Private Network)   │
                                      └────────────────┼─────────────────────┘
                                                       │
┌──────────────────────────────────────────────────────┼──────────────────────┐
│  VPC (10.0.0.0/16)                                   │                      │
│                                                      │                      │
│  ┌───────────────────────────────────────────────────▼──────────────────┐  │
│  │ Private Subnets (10.0.10.0/24, 10.0.11.0/24)                          │  │
│  │                                                                        │  │
│  │  ┌──────────────────────────────────────────────────────────────┐    │  │
│  │  │ RDS PostgreSQL                                                │    │  │
│  │  │ • Identifier: aws-demo-apprunner-db                           │    │  │
│  │  │ • Instance Class: db.t3.micro                                 │    │  │
│  │  │ • Engine: PostgreSQL 18.1                                     │    │  │
│  │  │ • Multi-AZ: Optional                                          │    │  │
│  │  │ • Security Group: rds-sg                                      │    │  │
│  │  │   - Inbound: 5432 from app-runner-sg                          │    │  │
│  │  │ • NOT publicly accessible                                     │    │  │
│  │  │                                                                │    │  │
│  │  │ Endpoint: aws-demo-db.xxxxx.eu-west-1.rds.amazonaws.com:5432 │    │  │
│  │  └──────────────────────────────────────────────────────────────┘    │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                      External Services (AWS Managed)                         │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────┐           │
│  │  Amazon ECR (Elastic Container Registry)                      │           │
│  │  • aws-demo-backend:latest                                    │           │
│  │  • aws-demo-frontend:latest                                   │           │
│  │                                                                │           │
│  │  App Runner pulls images automatically on deploy              │           │
│  │  IAM role grants ECR access (created by App Runner)           │           │
│  └──────────────────────────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Key App Runner Concepts:**

• **Fully Managed**: No infrastructure management (serverless containers)
• **Auto HTTPS**: SSL/TLS certificates provisioned automatically
• **Auto Scaling**: Based on concurrent requests (configurable)
• **VPC Connector**: Allows App Runner to access private VPC resources (RDS)
• **Source Types**: ECR image, GitHub repository, or Bitbucket
• **Deployment**: Automatic on image push to ECR (or manual trigger)

**Networking Details:**

• **Frontend Service**: Public internet → No VPC connector needed
• **Backend Service**: 
  - Public internet access for API requests
  - VPC connector for private database access
  - Outbound traffic goes through VPC subnets

**Security:**

• Each service has its own IAM instance role
• Environment variables encrypted at rest
• HTTPS enforced (HTTP redirects to HTTPS)
• VPC security groups control database access

**Traffic Flow:**

**Frontend:**
1. User → `https://xxxxx.awsapprunner.com` (auto HTTPS)
2. App Runner → Routes to frontend container instance
3. Nginx serves React static files
4. JavaScript makes API calls to backend App Runner URL

**Backend:**
1. Frontend JavaScript → `https://yyyyy.awsapprunner.com/api/messages`
2. App Runner → Routes to backend container instance
3. Spring Boot → Via VPC Connector → RDS in private subnet
4. Response flows back through App Runner → Frontend

**Scaling Behavior:**
• Concurrency target: 100 requests per instance (configurable)
• If traffic exceeds capacity → Auto-scale up (max: 10 instances)
• If traffic decreases → Scale down to min: 1 instance
• Scale-to-zero: Not supported (min 1 instance always running)
```

## Cost Estimate (us-east-1)

| Resource | Configuration | Monthly Cost |
|----------|---------------|--------------|
| App Runner Backend | 0.25 vCPU, 0.5GB (provisioned) | ~$15 |
| App Runner Frontend | 0.25 vCPU, 0.5GB | ~$15 |
| RDS PostgreSQL | db.t3.micro | ~$13 |
| VPC Connector | - | ~$0 |
| **Total** | | **~$43/month** |

*Note: App Runner also charges per request ($0.000007/request) which can add up*

## Advantages of App Runner

✅ Simplest deployment option
✅ Automatic HTTPS certificates
✅ Built-in auto-scaling (including scale to zero)
✅ No infrastructure to manage
✅ Automatic deployments from ECR
✅ Pay per use (can scale to zero)

## Disadvantages

❌ Limited customization
❌ No control over load balancer settings
❌ Requires VPC Connector for private resources
❌ Higher per-request costs at scale
❌ Limited to container or source code deployments

---

# Manual Deployment Steps

## Prerequisites

1. Docker images pushed to ECR
2. AWS CLI configured
3. VPC with private subnets for RDS

## Step 1: Push Docker Images to ECR

```bash
# Get AWS account ID and region
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=us-east-1

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and push backend
cd backend
docker build -t aws-demo-backend .
docker tag aws-demo-backend:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/aws-demo-backend:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/aws-demo-backend:latest

# Build and push frontend
cd ../frontend
docker build -t aws-demo-frontend .
docker tag aws-demo-frontend:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/aws-demo-frontend:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/aws-demo-frontend:latest
```

## Step 2: Create IAM Role for App Runner ECR Access

```bash
# Create trust policy
cat > apprunner-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "build.apprunner.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create role
aws iam create-role \
  --role-name aws-demo-apprunner-ecr-role \
  --assume-role-policy-document file://apprunner-trust-policy.json

# Attach ECR policy
aws iam attach-role-policy \
  --role-name aws-demo-apprunner-ecr-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess

# Get role ARN
export ECR_ACCESS_ROLE_ARN=$(aws iam get-role --role-name aws-demo-apprunner-ecr-role --query 'Role.Arn' --output text)
```

## Step 3: Create VPC Connector (for RDS access)

```bash
# Create VPC Connector
aws apprunner create-vpc-connector \
  --vpc-connector-name aws-demo-vpc-connector \
  --subnets subnet-xxxxx subnet-yyyyy \
  --security-groups sg-xxxxx

export VPC_CONNECTOR_ARN=$(aws apprunner list-vpc-connectors --query "VpcConnectors[?VpcConnectorName=='aws-demo-vpc-connector'].VpcConnectorArn" --output text)
```

## Step 4: Create Backend App Runner Service

```bash
cat > backend-apprunner.json << EOF
{
  "ServiceName": "aws-demo-backend",
  "SourceConfiguration": {
    "AuthenticationConfiguration": {
      "AccessRoleArn": "$ECR_ACCESS_ROLE_ARN"
    },
    "AutoDeploymentsEnabled": true,
    "ImageRepository": {
      "ImageIdentifier": "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/aws-demo-backend:latest",
      "ImageRepositoryType": "ECR",
      "ImageConfiguration": {
        "Port": "8080",
        "RuntimeEnvironmentVariables": {
          "DATABASE_URL": "jdbc:postgresql://YOUR_RDS_ENDPOINT:5432/awsdemo",
          "DATABASE_USER": "postgres",
          "DATABASE_PASSWORD": "YourSecurePassword123"
        }
      }
    }
  },
  "InstanceConfiguration": {
    "Cpu": "0.25 vCPU",
    "Memory": "0.5 GB"
  },
  "NetworkConfiguration": {
    "EgressConfiguration": {
      "EgressType": "VPC",
      "VpcConnectorArn": "$VPC_CONNECTOR_ARN"
    }
  },
  "HealthCheckConfiguration": {
    "Protocol": "HTTP",
    "Path": "/api/messages",
    "Interval": 10,
    "Timeout": 5,
    "HealthyThreshold": 1,
    "UnhealthyThreshold": 5
  },
  "AutoScalingConfigurationArn": "arn:aws:apprunner:$AWS_REGION:$AWS_ACCOUNT_ID:autoscalingconfiguration/DefaultConfiguration/1/00000000000000000000000000000001"
}
EOF

aws apprunner create-service --cli-input-json file://backend-apprunner.json

# Wait for service to be running
aws apprunner list-services --query "ServiceSummaryList[?ServiceName=='aws-demo-backend'].Status" --output text
```

## Step 5: Create Frontend App Runner Service

```bash
# Get backend URL first
export BACKEND_URL=$(aws apprunner list-services --query "ServiceSummaryList[?ServiceName=='aws-demo-backend'].ServiceUrl" --output text)

cat > frontend-apprunner.json << EOF
{
  "ServiceName": "aws-demo-frontend",
  "SourceConfiguration": {
    "AuthenticationConfiguration": {
      "AccessRoleArn": "$ECR_ACCESS_ROLE_ARN"
    },
    "AutoDeploymentsEnabled": true,
    "ImageRepository": {
      "ImageIdentifier": "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/aws-demo-frontend:latest",
      "ImageRepositoryType": "ECR",
      "ImageConfiguration": {
        "Port": "80"
      }
    }
  },
  "InstanceConfiguration": {
    "Cpu": "0.25 vCPU",
    "Memory": "0.5 GB"
  },
  "HealthCheckConfiguration": {
    "Protocol": "HTTP",
    "Path": "/",
    "Interval": 10,
    "Timeout": 5,
    "HealthyThreshold": 1,
    "UnhealthyThreshold": 5
  }
}
EOF

aws apprunner create-service --cli-input-json file://frontend-apprunner.json
```

## Step 6: Update Frontend Configuration

> ⚠️ **IMPORTANT**: With App Runner, each service gets its own URL. The frontend needs to know the backend URL.

**Option A: Use environment variable in React (Recommended)**

This avoids nginx proxy issues and calls the backend directly:

```bash
# Rebuild frontend with backend URL
cd frontend

# Get backend URL
export BACKEND_URL=$(aws apprunner list-services --query "ServiceSummaryList[?ServiceName=='aws-demo-backend'].ServiceUrl" --output text)
echo "Backend URL: https://$BACKEND_URL"

# Create production environment file
echo "VITE_API_URL=https://$BACKEND_URL" > .env.production

# Rebuild and push
npm run build
docker build -t aws-demo-frontend .
docker tag aws-demo-frontend:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/aws-demo-frontend:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/aws-demo-frontend:latest

# App Runner will auto-deploy
cd ..
```

**Option B: Nginx proxy (more complex)**

> ⚠️ Make sure `frontend/nginx.conf` does NOT have a proxy to `http://backend:8080` - that only works with docker-compose.

If you need nginx to proxy, update it to proxy to the App Runner backend URL:

```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy API to backend App Runner service
    location /api {
        proxy_pass https://YOUR_BACKEND_SERVICE_URL;
        proxy_set_header Host YOUR_BACKEND_SERVICE_URL;
        proxy_ssl_server_name on;
    }
}
```

## Step 7: Configure Custom Auto Scaling (Optional)

```bash
cat > autoscaling-config.json << 'EOF'
{
  "AutoScalingConfigurationName": "aws-demo-autoscaling",
  "MaxConcurrency": 100,
  "MinSize": 1,
  "MaxSize": 10
}
EOF

aws apprunner create-auto-scaling-configuration --cli-input-json file://autoscaling-config.json

# Update service with new config
aws apprunner update-service \
  --service-arn YOUR_SERVICE_ARN \
  --auto-scaling-configuration-arn YOUR_AUTOSCALING_ARN
```

## Step 8: Test the Deployment

```bash
# Get service URLs
aws apprunner list-services --query "ServiceSummaryList[*].[ServiceName,ServiceUrl]" --output table

# Test backend
curl https://YOUR_BACKEND_URL/api/messages

# Test frontend
curl https://YOUR_FRONTEND_URL/
```

---

# Alternative: Frontend on S3 + CloudFront

For better performance and cost efficiency, deploy frontend to S3:

```bash
cd frontend
npm run build

# Create S3 bucket
aws s3 mb s3://aws-demo-frontend-$AWS_ACCOUNT_ID

# Upload files
aws s3 sync dist/ s3://aws-demo-frontend-$AWS_ACCOUNT_ID --delete

# Create CloudFront distribution pointing to:
# - S3 for static files (default)
# - App Runner backend for /api/*
```

---

# Updating Services

App Runner automatically deploys when you push new images to ECR:

```bash
# Push new backend image
docker build -t aws-demo-backend ./backend
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/aws-demo-backend:latest

# App Runner detects and deploys automatically!
# Or trigger manual deployment:
aws apprunner start-deployment --service-arn YOUR_SERVICE_ARN
```

---

# Viewing Logs

```bash
# View logs in CloudWatch
aws logs describe-log-groups --log-group-name-prefix /aws/apprunner

# Stream logs
aws logs tail /aws/apprunner/aws-demo-backend/YOUR_SERVICE_ID/application --follow
```

---

# Cleanup

```bash
# Delete App Runner services
aws apprunner delete-service --service-arn $(aws apprunner list-services --query "ServiceSummaryList[?ServiceName=='aws-demo-backend'].ServiceArn" --output text)
aws apprunner delete-service --service-arn $(aws apprunner list-services --query "ServiceSummaryList[?ServiceName=='aws-demo-frontend'].ServiceArn" --output text)

# Delete VPC Connector
aws apprunner delete-vpc-connector --vpc-connector-arn $VPC_CONNECTOR_ARN

# Delete IAM role
aws iam detach-role-policy --role-name aws-demo-apprunner-ecr-role --policy-arn arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess
aws iam delete-role --role-name aws-demo-apprunner-ecr-role
```
