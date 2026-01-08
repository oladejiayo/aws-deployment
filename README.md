# AWS Demo App - Deployment Guide

A simple Spring Boot + React + PostgreSQL application demonstrating 4 different AWS deployment options.

## Quick Start (Local Development)

```bash
docker-compose up --build
```
- Frontend: http://localhost
- Backend API: http://localhost:8080/api/messages

---

## Prerequisites for AWS Deployment

### Required Tools

| Tool | Purpose | Installation |
|------|---------|--------------|
| **AWS CLI** | Interact with AWS services | [Download](https://aws.amazon.com/cli/) |
| **Terraform** | Infrastructure as Code | [Download](https://developer.hashicorp.com/terraform/install) |
| **Docker** | Build container images | [Download](https://www.docker.com/products/docker-desktop/) |

### AWS Account Setup

1. **Create AWS Account**: https://aws.amazon.com/free/

2. **Create IAM User** (don't use root!):
   - AWS Console → IAM → Users → Create user
   - Attach policy: `AdministratorAccess`
   - Create access key for CLI

3. **Configure AWS CLI**:
   ```bash
   aws configure
   # Enter: Access Key ID, Secret Key, Region (us-east-1), Output (json)
   ```

4. **Verify Setup**:
   ```bash
   aws sts get-caller-identity
   ```

📖 **[Detailed Prerequisites Guide](infrastructure/README.md#prerequisites-all-options)**

---

## AWS Deployment Options Comparison

| Feature | EC2 | ECS | Elastic Beanstalk | App Runner |
|---------|-----|-----|-------------------|------------|
| **Complexity** | High | Medium | Low | Very Low |
| **Control** | Maximum | High | Medium | Low |
| **Auto-scaling** | Manual setup | Built-in | Built-in | Built-in |
| **Cost (estimated)** | ~$46/mo | ~$60-90/mo | ~$31/mo | ~$43/mo |
| **Best For** | Custom requirements | Container orchestration | Quick deployment | Simplest option |
| **Setup Time** | ~2 hours | ~1 hour | ~30 mins | ~15 mins |

### Which Option Should I Choose?

| Your Situation | Recommendation |
|----------------|----------------|
| First time with AWS | **App Runner** - simplest path |
| Want to learn AWS properly | **ECS** - industry standard |
| Cost is the priority | **Elastic Beanstalk** - cheapest |
| Need full control | **EC2** - maximum flexibility |

---

## Deployment Steps Overview

### Step 1: Deploy Common Infrastructure

First, deploy shared resources (VPC, RDS, ECR):

```bash
cd infrastructure/common/terraform

# Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Deploy
terraform init
terraform plan
terraform apply
```

### Step 2: Push Docker Images to ECR

```bash
cd infrastructure/scripts

# Linux/Mac
chmod +x push-to-ecr.sh
./push-to-ecr.sh

# Windows PowerShell
.\push-to-ecr.ps1
```

### Step 3: Choose Your Deployment Option

#### Option 1: EC2
```bash
cd infrastructure/1-ec2/terraform
terraform init
terraform apply -var="key_name=your-key" -var="db_password=YourPassword123"
```
📖 [Detailed EC2 Guide](infrastructure/1-ec2/manual-steps.md)

#### Option 2: ECS (Fargate)
```bash
cd infrastructure/2-ecs/terraform
terraform init
terraform apply -var="db_password=YourPassword123"
```
📖 [Detailed ECS Guide](infrastructure/2-ecs/manual-steps.md)

#### Option 3: Elastic Beanstalk
```bash
cd infrastructure/3-elastic-beanstalk/terraform
terraform init
terraform apply -var="db_password=YourPassword123"

# Upload frontend to S3
aws s3 sync frontend/dist/ s3://$(terraform output -raw s3_bucket_name)
```
📖 [Detailed Elastic Beanstalk Guide](infrastructure/3-elastic-beanstalk/manual-steps.md)

#### Option 4: App Runner
```bash
cd infrastructure/4-app-runner/terraform
terraform init
terraform apply -var="db_password=YourPassword123"
```
📖 [Detailed App Runner Guide](infrastructure/4-app-runner/manual-steps.md)

---

## Project Structure

```
aws-deployment/
├── backend/                          # Spring Boot API
│   ├── src/main/java/...
│   ├── pom.xml
│   └── Dockerfile
├── frontend/                         # React (Vite)
│   ├── src/
│   ├── package.json
│   ├── Dockerfile
│   └── nginx.conf
├── infrastructure/
│   ├── README.md                     # Infrastructure overview
│   ├── common/terraform/             # Shared resources (VPC, RDS, ECR)
│   ├── 1-ec2/
│   │   ├── manual-steps.md           # Step-by-step CLI guide
│   │   └── terraform/                # IaC
│   ├── 2-ecs/
│   │   ├── manual-steps.md
│   │   ├── terraform/
│   │   └── task-definitions/
│   ├── 3-elastic-beanstalk/
│   │   ├── manual-steps.md
│   │   ├── terraform/
│   │   └── .ebextensions/
│   ├── 4-app-runner/
│   │   ├── manual-steps.md
│   │   └── terraform/
│   └── scripts/                      # Helper scripts
├── docker-compose.yml
└── README.md
```

---

## When to Use Each Option

### Choose **EC2** if you need:
- Full control over the operating system
- Custom software installations
- Specific networking configurations
- Cost optimization for predictable workloads

### Choose **ECS** if you need:
- Container orchestration
- Fine-grained scaling control
- Service discovery between containers
- Integration with other AWS services

### Choose **Elastic Beanstalk** if you need:
- Fastest time to deployment
- Managed platform updates
- Built-in monitoring and logging
- Easy rollback capabilities

### Choose **App Runner** if you need:
- Simplest possible deployment
- Automatic HTTPS
- Pay-per-request pricing
- No infrastructure management

---

## Environment Variables

### Backend
| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | PostgreSQL JDBC URL |
| `DATABASE_USER` | Database username |
| `DATABASE_PASSWORD` | Database password |
| `PORT` | Server port (default: 8080) |

### Frontend
| Variable | Description |
|----------|-------------|
| `VITE_API_URL` | Backend API URL (for production builds) |

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /api/messages | Get all messages |
| POST | /api/messages | Create message |
| DELETE | /api/messages/{id} | Delete message |

---

## Cleanup

To avoid ongoing charges, destroy resources when done:

```bash
# Destroy specific deployment
cd infrastructure/[1-ec2|2-ecs|3-elastic-beanstalk|4-app-runner]/terraform
terraform destroy

# Destroy common infrastructure (do this last)
cd infrastructure/common/terraform
terraform destroy
```
