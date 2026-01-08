# EC2 Deployment with Terraform

This Terraform configuration deploys the AWS Demo application with flexible frontend options.

## Frontend Deployment Options

### Option A: EC2 + Nginx (Default: Disabled)
- Frontend runs on EC2 instance with Nginx
- Simpler architecture, all services in EC2
- Cost: ~$46/month

### Option B: S3 + CloudFront (Default: **Enabled**)
- Frontend served from S3 via CloudFront CDN
- Better performance, lower cost, global distribution
- Cost: ~$39/month
- **Recommended for production**

## Prerequisites

1. **Common Infrastructure Deployed**: Must run `common/terraform` first
2. **Docker Images Pushed to ECR**: Frontend and backend images must be in ECR
3. **EC2 Key Pair Created**: For SSH access to backend instance
4. **AWS CLI Configured**: With appropriate credentials

## Quick Start

### 1. Initialize Terraform

```bash
cd infrastructure/1-ec2/terraform
terraform init
```

### 2. Create `terraform.tfvars`

```hcl
# Required
key_name    = "your-key-pair-name"
db_password = "your-secure-password"

# Optional - defaults shown
aws_region               = "us-east-1"
project_name             = "aws-demo"
instance_type            = "t3.micro"
db_username              = "postgres"
frontend_deployment_type = "s3_cloudfront"  # or "ec2"
```

### 3. Deploy

```bash
# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

## Choosing Frontend Deployment Type

### Use EC2 Frontend When:
- Learning AWS EC2 fundamentals
- Need server-side rendering or custom logic
- Want all services in one place
- Don't need global distribution

Set in `terraform.tfvars`:
```hcl
frontend_deployment_type = "ec2"
```

### Use S3 + CloudFront When:
- Deploying to production
- Want best performance and lowest cost
- Need global content delivery
- Have static React/Vue/Angular app

Set in `terraform.tfvars`:
```hcl
frontend_deployment_type = "s3_cloudfront"
```

## Post-Deployment Steps

### For EC2 Frontend (frontend_deployment_type = "ec2")

1. Get the application URL:
```bash
terraform output application_url
```

2. Wait 2-3 minutes for instances to boot and pass health checks

3. Test the application:
```bash
ALB_DNS=$(terraform output -raw alb_dns_name)
curl http://$ALB_DNS/
curl http://$ALB_DNS/api/messages
```

### For S3 + CloudFront Frontend (frontend_deployment_type = "s3_cloudfront")

1. Build and upload the frontend:
```bash
# Build the frontend with the ALB URL
cd ../../../frontend
ALB_DNS=$(cd ../infrastructure/1-ec2/terraform && terraform output -raw alb_dns_name)

cat > .env.production << EOF
VITE_API_URL=http://$ALB_DNS
EOF

npm run build

# Upload to S3
BUCKET_NAME=$(cd ../infrastructure/1-ec2/terraform && terraform output -raw s3_bucket_name)

aws s3 sync dist/ s3://$BUCKET_NAME/ \
  --delete \
  --cache-control "public, max-age=31536000" \
  --exclude "index.html"

aws s3 cp dist/index.html s3://$BUCKET_NAME/index.html \
  --cache-control "no-cache, no-store, must-revalidate"
```

2. Get the CloudFront URL:
```bash
cd ../infrastructure/1-ec2/terraform
terraform output cloudfront_domain
```

3. Wait 15-20 minutes for CloudFront distribution to deploy globally

4. Test the application:
```bash
CLOUDFRONT_DOMAIN=$(terraform output -raw cloudfront_domain)
echo "Frontend: https://$CLOUDFRONT_DOMAIN"

# Test backend API
ALB_DNS=$(terraform output -raw alb_dns_name)
curl http://$ALB_DNS/api/messages
```

## Updating Frontend (S3 + CloudFront)

When you make frontend changes:

```bash
cd frontend
npm run build

BUCKET_NAME=$(cd ../infrastructure/1-ec2/terraform && terraform output -raw s3_bucket_name)
CF_DIST_ID=$(cd ../infrastructure/1-ec2/terraform && terraform output -raw cloudfront_distribution_id)

# Upload new files
aws s3 sync dist/ s3://$BUCKET_NAME/ \
  --delete \
  --cache-control "public, max-age=31536000" \
  --exclude "index.html"

aws s3 cp dist/index.html s3://$BUCKET_NAME/index.html \
  --cache-control "no-cache, no-store, must-revalidate"

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id $CF_DIST_ID \
  --paths "/*"
```

## Outputs

| Output | Description |
|--------|-------------|
| `alb_dns_name` | ALB DNS name (for backend API) |
| `application_url` | Full application URL (frontend) |
| `backend_instance_id` | Backend EC2 instance ID |
| `backend_public_ip` | Backend EC2 public IP |
| `frontend_instance_id` | Frontend EC2 instance ID (EC2 mode only) |
| `frontend_public_ip` | Frontend EC2 public IP (EC2 mode only) |
| `s3_bucket_name` | S3 bucket name (S3+CloudFront mode only) |
| `cloudfront_domain` | CloudFront domain (S3+CloudFront mode only) |
| `cloudfront_distribution_id` | CloudFront distribution ID (S3+CloudFront mode only) |

## Architecture

### EC2 Frontend Architecture
```
Internet → ALB → Backend EC2 (Port 8080)
            ↓
            Frontend EC2 (Port 80)
            ↓
            RDS PostgreSQL
```

### S3 + CloudFront Frontend Architecture
```
Internet → CloudFront → S3 (Static Files)
        ↓
        ALB → Backend EC2 (Port 8080)
              ↓
              RDS PostgreSQL
```

## Cleanup

```bash
# Destroy all resources
terraform destroy

# If using S3+CloudFront, empty the bucket first:
BUCKET_NAME=$(terraform output -raw s3_bucket_name)
aws s3 rm s3://$BUCKET_NAME/ --recursive

# Then destroy
terraform destroy
```

## Troubleshooting

### EC2 Frontend Issues

```bash
# Check instance status
terraform output backend_instance_id
aws ec2 describe-instance-status --instance-ids <ID>

# SSH into instances
ssh -i your-key.pem ec2-user@$(terraform output -raw backend_public_ip)
sudo docker logs backend
```

### S3 + CloudFront Issues

```bash
# Check CloudFront status
CF_DIST_ID=$(terraform output -raw cloudfront_distribution_id)
aws cloudfront get-distribution --id $CF_DIST_ID

# Check S3 bucket contents
BUCKET_NAME=$(terraform output -raw s3_bucket_name)
aws s3 ls s3://$BUCKET_NAME/ --recursive

# Test CloudFront cache
curl -I https://$(terraform output -raw cloudfront_domain)
```

### Common Issues

1. **CloudFront 404 errors**: Distribution still deploying (15-20 minutes)
2. **API CORS errors**: Frontend built with wrong ALB URL - rebuild with correct URL
3. **Health check failures**: Check security groups allow ALB → EC2 traffic
4. **S3 403 errors**: Check bucket policy allows CloudFront OAI access

## Cost Optimization

- Use `t3.micro` instances (included in free tier)
- Enable S3 lifecycle policies to clean up old versions
- Use CloudFront `PriceClass_100` (already configured) for lower data transfer costs
- Consider Reserved Instances for long-term deployments
