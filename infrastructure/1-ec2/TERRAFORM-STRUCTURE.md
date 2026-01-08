# Terraform Deployment Structure

The Terraform deployment has been organized into separate directories for each deployment option, matching the manual deployment structure.

## Directory Structure

```
infrastructure/
├── common/
│   └── terraform/              # Shared infrastructure (VPC, RDS, ECR)
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars
│
└── 1-ec2/
    ├── README.md              # Overview of both options
    ├── manual-steps.md        # Manual CLI deployment guide
    │
    ├── option-a-ec2/          # Option A: EC2 for both
    │   └── terraform/
    │       ├── main.tf
    │       ├── variables.tf
    │       ├── outputs.tf
    │       ├── terraform.tfvars
    │       ├── README.md      # Option A deployment guide
    │       └── scripts/
    │           ├── backend-userdata.sh
    │           └── frontend-userdata.sh
    │
    └── option-b-s3-cloudfront/ # Option B: S3 + CloudFront
        └── terraform/
            ├── main.tf
            ├── variables.tf
            ├── outputs.tf
            ├── terraform.tfvars
            ├── README.md       # Option B deployment guide
            └── scripts/
                └── backend-userdata.sh
```

## Deployment Options

### Option A: EC2 for Both Frontend and Backend
📁 **Location**: `infrastructure/1-ec2/option-a-ec2/terraform/`

**Architecture**:
```
Internet → ALB → Frontend EC2 (Port 80)
                └─ Backend EC2 (Port 8080) → RDS
```

**Resources**:
- 2 EC2 instances (frontend + backend)
- Application Load Balancer
- 2 Target Groups
- IAM Role & Instance Profile

**Cost**: ~$47.50/month

**Use when**:
- Simple traditional setup preferred
- Need SSH access to frontend
- Server-side rendering required
- Team familiar with EC2 management

### Option B: S3 + CloudFront for Frontend
📁 **Location**: `infrastructure/1-ec2/option-b-s3-cloudfront/terraform/`

**Architecture**:
```
Internet → CloudFront → S3 Bucket (Frontend)
        → ALB → Backend EC2 (Port 8080) → RDS
```

**Resources**:
- 1 EC2 instance (backend only)
- S3 Bucket with versioning
- CloudFront Distribution
- CloudFront Origin Access Identity
- Application Load Balancer
- IAM Role & Instance Profile

**Cost**: ~$41.50/month (13% savings)

**Use when**:
- Cost optimization needed
- Global user base (CloudFront edge locations)
- Static SPA (React, Vue, Angular)
- HTTPS by default required
- Better scalability needed

## Quick Start Guide

### 1. Deploy Common Infrastructure (Required for Both Options)

```powershell
cd infrastructure/common/terraform
terraform init
terraform validate
terraform apply
```

### 2. Choose Your Option

**For Option A (EC2)**:
```powershell
cd ../../1-ec2/option-a-ec2/terraform
```

**For Option B (S3 + CloudFront)**:
```powershell
cd ../../1-ec2/option-b-s3-cloudfront/terraform
```

### 3. Follow the README

Each option has a detailed README with:
- Prerequisites
- Configuration steps
- Deployment commands
- Testing procedures
- Update workflows
- Troubleshooting guide

## Key Differences

| Aspect | Option A | Option B |
|--------|----------|----------|
| **Frontend** | EC2 Instance | S3 + CloudFront |
| **Files** | 5 files + 2 scripts | 5 files + 1 script |
| **Resources Created** | ~13 resources | ~15 resources |
| **Deployment Time** | 5-10 minutes | 20-25 minutes |
| **Monthly Cost** | $47.50 | $41.50 |
| **HTTPS** | Requires setup | Included |
| **SSH to Frontend** | ✅ Yes | ❌ No |
| **Global CDN** | ❌ No | ✅ Yes |
| **Auto Scaling** | Manual (ASG) | Automatic |

## File Organization

### Common Files (Both Options)

- **main.tf**: Main infrastructure definition
- **variables.tf**: Input variables
- **outputs.tf**: Output values
- **terraform.tfvars**: Configuration values
- **README.md**: Deployment guide
- **scripts/backend-userdata.sh**: Backend EC2 initialization

### Option A Specific

- **scripts/frontend-userdata.sh**: Frontend EC2 initialization
- Frontend EC2 instance resource
- Frontend target group and attachment
- ALB forwards root to frontend

### Option B Specific

- S3 bucket resources (bucket, versioning, public access block)
- CloudFront distribution and OAI
- S3 bucket policy for CloudFront
- ALB returns 404 for root (frontend via CloudFront)

## Migration Between Options

To switch from one option to another:

```powershell
# 1. Destroy current option
cd infrastructure/1-ec2/<current-option>/terraform
terraform destroy

# 2. Deploy new option
cd ../../../1-ec2/<new-option>/terraform
terraform init
terraform apply
```

⚠️ **Note**: Common infrastructure remains unchanged.

## Documentation

- **TERRAFORM-DEPLOYMENT-GUIDE.md**: Detailed step-by-step guide (Option B)
- **infrastructure/1-ec2/README.md**: Overview of both options
- **option-a-ec2/terraform/README.md**: Option A specific guide
- **option-b-s3-cloudfront/terraform/README.md**: Option B specific guide
- **manual-steps.md**: Manual CLI deployment (both options)

## Benefits of This Structure

✅ **Clear Separation**: Each option is self-contained
✅ **No Conditionals**: Cleaner Terraform code without `count` conditionals
✅ **Easy Comparison**: Side-by-side file comparison between options
✅ **Simpler Variables**: No `frontend_deployment_type` switching needed
✅ **Independent Updates**: Update one option without affecting the other
✅ **Better Documentation**: Option-specific guides for each use case
✅ **Matches Manual Structure**: Consistent with manual deployment organization

## Recommendation

🌟 **Recommended**: Option B (S3 + CloudFront)

Unless you specifically need EC2 for the frontend, Option B provides:
- 13% cost savings
- Better global performance
- Automatic scaling
- HTTPS included
- Modern architecture
