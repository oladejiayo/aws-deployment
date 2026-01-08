# AWS Deployment Infrastructure

This directory contains infrastructure code and documentation for deploying the AWS Demo App using multiple AWS deployment options.

## 📊 Quick Comparison

| Option | Monthly Cost | Setup Time | Management | Best For |
|--------|-------------|------------|------------|----------|
| **[EC2 (Option A)](#1-ec2-deployment)** | $47 | 10 min | High | Cost-sensitive, full control |
| **[EC2 (Option B)](#1-ec2-deployment)** | $41.50 | 15 min | High | Global users, S3+CloudFront |
| **[ECS Fargate](#2-ecs-deployment)** | $81 | 12 min | Low | Containers, auto-scaling |
| **[Elastic Beanstalk](#3-elastic-beanstalk)** | $49 | 20 min | Medium | PaaS, traditional apps |
| **[App Runner](#4-app-runner)** | $16-$134 | 5 min | None | Simplest, variable traffic |

📖 **[View Detailed Comparison](DEPLOYMENT-OPTIONS-COMPARISON.md)**

## 📁 Directory Structure

```
infrastructure/
├── common/                            # ⚠️ Deploy this FIRST (required by all options)
│   └── terraform/                     # VPC, RDS, ECR, Security Groups
│
├── 1-ec2/                             # EC2 Deployment ($41-$47/month)
│   ├── README.md                      # Overview of EC2 options
│   ├── option-a-ec2/                  # Traditional: Both on EC2
│   │   └── terraform/                 # ✅ Complete deployment guide
│   ├── option-b-s3-cloudfront/        # Modern: S3+CloudFront + EC2
│   │   └── terraform/                 # ✅ Complete deployment guide
│   └── manual-steps.md                # CLI-based deployment
│
├── 2-ecs/                             # ECS Fargate ($81/month)
│   ├── README.md                      # Overview of ECS
│   ├── terraform/                     # ✅ Complete deployment guide
│   │   ├── README.md
│   │   └── terraform.tfvars
│   ├── manual-steps.md
│   └── task-definitions/
│
├── 3-elastic-beanstalk/               # Elastic Beanstalk ($49/month)
│   ├── README.md                      # Overview of EB
│   ├── terraform/                     # ✅ Complete deployment guide
│   │   ├── README.md
│   │   └── terraform.tfvars
│   ├── manual-steps.md
│   └── .ebextensions/
│
├── 4-app-runner/                      # App Runner ($16-$134/month)
│   ├── README.md                      # Overview of App Runner
│   ├── terraform/                     # ✅ Complete deployment guide
│   │   ├── README.md
│   │   └── terraform.tfvars
│   └── manual-steps.md
│
├── DEPLOYMENT-OPTIONS-COMPARISON.md   # 📊 Detailed comparison guide
└── README.md                          # This file
```

## 🚀 Quick Start

### Step 1: Choose Your Deployment Option

Not sure which to choose? **[Read the detailed comparison](DEPLOYMENT-OPTIONS-COMPARISON.md)**

**Quick recommendations**:
- 💰 **Lowest cost (24/7)**: [EC2 Option A](1-ec2/option-a-ec2/terraform/README.md)
- 🌍 **Global performance**: [EC2 Option B](1-ec2/option-b-s3-cloudfront/terraform/README.md)
- 🐳 **Containers & scale**: [ECS Fargate](2-ecs/terraform/README.md)
- 🎯 **PaaS simplicity**: [Elastic Beanstalk](3-elastic-beanstalk/terraform/README.md)
- 🚀 **Easiest & fastest**: [App Runner](4-app-runner/terraform/README.md)

### Step 2: Deploy Common Infrastructure (Required)

All options require common infrastructure (VPC, RDS, ECR):

```powershell
cd common/terraform
terraform init
terraform apply
```

### Step 3: Follow Your Chosen Option's README

Each option has a complete step-by-step guide in its `terraform/README.md` file.

---

## 📋 Deployment Guides by Option

### 1. EC2 Deployment

**Overview**: [1-ec2/README.md](1-ec2/README.md)

#### Option A: Traditional (Both on EC2)
- 📖 **Terraform Guide**: [option-a-ec2/terraform/README.md](1-ec2/option-a-ec2/terraform/README.md)
- 💰 **Cost**: $47/month
- ⏱️ **Setup**: 10 minutes
- ✅ **Best for**: Full control, SSH access, lowest cost

#### Option B: Modern (S3+CloudFront + EC2)
- 📖 **Terraform Guide**: [option-b-s3-cloudfront/terraform/README.md](1-ec2/option-b-s3-cloudfront/terraform/README.md)
- 💰 **Cost**: $41.50/month (13% savings)
- ⏱️ **Setup**: 25 minutes
- ✅ **Best for**: Global users, static SPA, HTTPS included

### 2. ECS Deployment

**Overview**: [2-ecs/README.md](2-ecs/README.md)

- 📖 **Terraform Guide**: [2-ecs/terraform/README.md](2-ecs/terraform/README.md)
- 💰 **Cost**: $81/month
- ⏱️ **Setup**: 12 minutes
- ✅ **Best for**: Container orchestration, auto-scaling, microservices

### 3. Elastic Beanstalk

**Overview**: [3-elastic-beanstalk/README.md](3-elastic-beanstalk/README.md)

- 📖 **Terraform Guide**: [3-elastic-beanstalk/terraform/README.md](3-elastic-beanstalk/terraform/README.md)
- 💰 **Cost**: $49/month
- ⏱️ **Setup**: 20 minutes
- ✅ **Best for**: PaaS simplicity, traditional Java/Python apps, managed infrastructure

### 4. App Runner

**Overview**: [4-app-runner/README.md](4-app-runner/README.md)

- 📖 **Terraform Guide**: [4-app-runner/terraform/README.md](4-app-runner/terraform/README.md)
- 💰 **Cost**: $16/month (low traffic) to $134/month (24/7)
- ⏱️ **Setup**: 5 minutes
- ✅ **Best for**: Simplest deployment, variable traffic, pay-per-use

---

## 📚 Additional Documentation

- 📊 **[Complete Comparison Guide](DEPLOYMENT-OPTIONS-COMPARISON.md)** - Detailed analysis of all options
- 🔧 **Manual Deployment**: Each option has a `manual-steps.md` for CLI-based deployment
- 🏗️ **Terraform Deployment**: Each option has a `terraform/README.md` with complete IaC guide

---

## ⚙️ Prerequisites (All Options)

### 1. Install Required Tools

| Tool | Version | Download |
|------|---------|----------|
| **AWS CLI** | v2.x | https://aws.amazon.com/cli/ |
| **Terraform** | v1.5+ | https://developer.hashicorp.com/terraform/install |
| **Docker** | Latest | https://www.docker.com/products/docker-desktop/ |

**Verify installations:**
```powershell
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
