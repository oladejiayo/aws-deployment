# EC2 Deployment Options

This directory contains two deployment options for the application using EC2 infrastructure.

## Available Options

### Option A: EC2 for Both Frontend and Backend
**Directory**: [option-a-ec2/terraform](option-a-ec2/terraform/)

Traditional deployment with both frontend and backend on separate EC2 instances.

**Architecture**: Internet → ALB → Frontend EC2 + Backend EC2 → RDS

**Best for**:
- Simple setup with consistent infrastructure
- Teams familiar with EC2 management
- Applications requiring server-side rendering
- When you need SSH access to frontend server

**Monthly Cost**: ~$32 (excluding common infrastructure)

### Option B: S3 + CloudFront for Frontend, EC2 for Backend
**Directory**: [option-b-s3-cloudfront/terraform](option-b-s3-cloudfront/terraform/)

Modern serverless frontend with CloudFront CDN and EC2 backend.

**Architecture**: Internet → CloudFront → S3 (Frontend) + ALB → Backend EC2 → RDS

**Best for**:
- Cost optimization (19% savings vs Option A)
- Global user base (CloudFront edge locations)
- Static SPA applications (React, Vue, Angular)
- HTTPS by default
- Better scalability and performance

**Monthly Cost**: ~$26 (excluding common infrastructure)

## Comparison

| Feature | Option A (EC2) | Option B (S3 + CloudFront) |
|---------|---------------|---------------------------|
| **Frontend Hosting** | EC2 Instance | S3 + CloudFront |
| **Backend Hosting** | EC2 Instance | EC2 Instance |
| **HTTPS** | Requires ACM setup | Included (CloudFront) |
| **Scalability** | Manual (ASG needed) | Automatic (S3/CloudFront) |
| **Global Distribution** | Single region | Edge locations worldwide |
| **Monthly Cost** | ~$32 | ~$26 |
| **Deployment Time** | ~5-10 min | ~20-25 min (CloudFront) |
| **Update Speed** | 2-3 min | 5-10 min (cache invalidation) |
| **Setup Complexity** | Low | Medium |
| **SSH Access** | Both instances | Backend only |

## Quick Start

### 1. Choose Your Option

Navigate to the option directory:

**Option A**:
```powershell
cd option-a-ec2/terraform
```

**Option B**:
```powershell
cd option-b-s3-cloudfront/terraform
```

### 2. Deploy Common Infrastructure First

Both options require common infrastructure (VPC, RDS, ECR):

```powershell
cd ..\..\..\..\common\terraform
terraform init
terraform apply
```

### 3. Follow Option-Specific README

Each option has detailed deployment instructions in its README.md:
- [Option A README](option-a-ec2/terraform/README.md)
- [Option B README](option-b-s3-cloudfront/terraform/README.md)

## Manual Deployment Alternative

If you prefer manual CLI deployment instead of Terraform, see:
- [manual-steps.md](manual-steps.md)

## Switching Between Options

You can switch between options, but:

1. **Destroy the current deployment first**:
   ```powershell
   terraform destroy
   ```

2. **Deploy the new option**:
   ```powershell
   cd ..\<new-option>\terraform
   terraform init
   terraform apply
   ```

⚠️ **Note**: Common infrastructure (VPC, RDS, ECR) is shared and should remain deployed.

## Recommended Option

**For most applications**: Choose **Option B (S3 + CloudFront)**
- Lower cost
- Better performance for global users
- Automatic scaling
- HTTPS included
- Modern architecture

**Choose Option A** only if you:
- Need server-side rendering on the frontend
- Require SSH access to frontend server
- Have very dynamic frontend that can't be static
- Want to minimize deployment complexity

## Cost Summary

### Option A (EC2 for Both)
| Service | Cost |
|---------|------|
| Frontend EC2 | $7.50 |
| Backend EC2 | $7.50 |
| ALB | $16.00 |
| Data Transfer | $1.00 |
| **Total** | **$32/month** |

### Option B (S3 + CloudFront)
| Service | Cost |
|---------|------|
| Backend EC2 | $7.50 |
| ALB | $16.00 |
| S3 (100MB) | $0.50 |
| CloudFront (1GB) | $1.00 |
| Data Transfer | $1.00 |
| **Total** | **$26/month** |

### Common Infrastructure (Both Options)
| Service | Cost |
|---------|------|
| RDS PostgreSQL (db.t3.micro) | $15.00 |
| ECR Storage | $0.50 |
| VPC/Networking | Free |
| **Total** | **$15.50/month** |

### Grand Total
- **Option A**: $47.50/month
- **Option B**: $41.50/month
- **Savings with Option B**: $6/month (13%)

## Support

For issues or questions:
1. Check the option-specific README
2. Review [manual-steps.md](manual-steps.md) for detailed explanations
3. Check AWS Console for resource status
4. Review Terraform state: `terraform show`
