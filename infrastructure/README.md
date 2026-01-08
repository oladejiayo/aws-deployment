# AWS Deployment Infrastructure

This directory contains infrastructure code and documentation for deploying the AWS Demo App using 4 different AWS deployment options.

## Deployment Options Overview

| Option | Best For | Complexity | Cost | Control |
|--------|----------|------------|------|---------|
| **EC2** | Full control, custom configs | High | Low-Medium | Maximum |
| **ECS** | Container orchestration | Medium | Medium | High |
| **Elastic Beanstalk** | Quick deployment, managed | Low | Medium | Medium |
| **App Runner** | Simplest container deployment | Very Low | Medium-High | Low |

## Directory Structure

```
infrastructure/
├── 1-ec2/                    # EC2 deployment
│   ├── terraform/            # IaC with Terraform
│   ├── manual-steps.md       # Step-by-step manual guide
│   └── scripts/              # Setup scripts
├── 2-ecs/                    # ECS deployment
│   ├── terraform/
│   ├── manual-steps.md
│   └── task-definitions/
├── 3-elastic-beanstalk/      # Elastic Beanstalk deployment
│   ├── terraform/
│   ├── manual-steps.md
│   └── .ebextensions/
├── 4-app-runner/             # App Runner deployment
│   ├── terraform/
│   └── manual-steps.md
└── common/                   # Shared resources (VPC, RDS)
    └── terraform/
```

## Prerequisites (All Options)

### 1. Install Required Tools

| Tool | Version | Download |
|------|---------|----------|
| **AWS CLI** | v2.x | https://aws.amazon.com/cli/ |
| **Terraform** | v1.5+ | https://developer.hashicorp.com/terraform/install |
| **Docker** | Latest | https://www.docker.com/products/docker-desktop/ |

**Verify installations:**
```bash
# Check all tools are installed
aws --version
terraform --version
docker --version
```

### 2. Create an AWS Account

If you don't have one: https://aws.amazon.com/free/

### 3. Create an IAM User (Don't use root account!)

1. Go to **AWS Console** → **IAM** → **Users** → **Create user**
2. Username: `aws-demo-admin`
3. Select **"Attach policies directly"**
4. Attach policy: `AdministratorAccess` (for learning; restrict in production)
5. Click **Create user**
6. Select the user → **Security credentials** tab → **Create access key**
7. Choose **"Command Line Interface (CLI)"** → Create and download credentials

### 4. Configure AWS CLI

```bash
aws configure
```

Enter when prompted:
| Prompt | Value |
|--------|-------|
| AWS Access Key ID | From step 3 |
| AWS Secret Access Key | From step 3 |
| Default region | `us-east-1` (recommended) |
| Default output format | `json` |

**Verify configuration:**
```bash
aws sts get-caller-identity
```

You should see your Account ID and User ARN.

### 5. Create EC2 Key Pair (Required for EC2 option only)

```bash
# Linux/Mac
aws ec2 create-key-pair --key-name aws-demo-key --query 'KeyMaterial' --output text > aws-demo-key.pem
chmod 400 aws-demo-key.pem

# Windows PowerShell
aws ec2 create-key-pair --key-name aws-demo-key --query 'KeyMaterial' --output text | Out-File -Encoding ascii aws-demo-key.pem
```

---

## Which Option Should You Choose?

| Your Situation | Recommended Option | Why |
|----------------|-------------------|-----|
| **First time deploying to AWS** | App Runner | Simplest, 15 mins setup |
| **Want to learn AWS properly** | ECS | Good balance of control & simplicity |
| **Cost is primary concern** | Elastic Beanstalk | Cheapest at ~$31/month |
| **Need maximum control** | EC2 | Full OS access, most customizable |
| **Production workload** | ECS or EC2 | Better scaling and control |

---

## Common Resources

All deployment options share:
- **VPC** with public/private subnets
- **RDS PostgreSQL** database
- **Security Groups**

Deploy common resources first:
```bash
cd common/terraform
terraform init
terraform apply
```

## Quick Comparison

### EC2
- ✅ Full control over infrastructure
- ✅ Lowest cost for predictable workloads
- ❌ Manual scaling and maintenance
- ❌ Most complex setup

### ECS
- ✅ Container orchestration built-in
- ✅ Auto-scaling capabilities
- ✅ Good balance of control and management
- ❌ More complex than managed services

### Elastic Beanstalk
- ✅ Fastest to deploy
- ✅ Built-in monitoring and scaling
- ✅ Easy rollbacks
- ❌ Less control over infrastructure

### App Runner
- ✅ Simplest deployment
- ✅ Automatic scaling and HTTPS
- ❌ Limited configuration options
- ❌ Higher cost per request
