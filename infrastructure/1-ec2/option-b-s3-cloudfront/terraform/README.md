# Option B: S3 + CloudFront for Frontend, EC2 for Backend

This Terraform configuration deploys the backend on EC2 and the frontend on S3 with CloudFront CDN for global distribution.

## Architecture

```
Internet
   |
   +-- CloudFront --> S3 Bucket (Frontend)
   |
   +-- Application Load Balancer --> Backend (EC2) --> RDS PostgreSQL
```

## Resources Created

- **1 EC2 Instance**: Backend only
- **S3 Bucket**: Static website hosting for frontend
- **CloudFront Distribution**: CDN for frontend with HTTPS
- **CloudFront OAI**: Secure S3 access without public bucket
- **Application Load Balancer**: Routes API traffic to backend
- **IAM Role**: For EC2 instance to access ECR
- **Security Groups**: Inherited from common infrastructure

## Benefits

- **Lower Cost**: ~13% savings compared to Option A
- **Better Performance**: CloudFront edge locations provide faster content delivery
- **HTTPS by Default**: CloudFront provides free SSL certificate
- **Scalability**: S3 and CloudFront handle high traffic automatically
- **Static Asset Optimization**: Automatic compression and caching

## Prerequisites

1. Deploy common infrastructure first:
   ```powershell
   cd ..\..\..\common\terraform
   terraform apply
   ```

2. Build and push backend Docker image to ECR:
   ```powershell
   # Get ECR URL from common infrastructure
   cd ..\..\..\common\terraform
   terraform output ecr_backend_url
   
   # Authenticate Docker to ECR
   aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.eu-west-1.amazonaws.com
   
   # Build and push backend
   cd ..\..\..\..\..\backend
   docker build -t aws-demo-backend .
   docker tag aws-demo-backend:latest <ECR_BACKEND_URL>:latest
   docker push <ECR_BACKEND_URL>:latest
   ```

3. Create EC2 key pair (if not exists):
   ```powershell
   aws ec2 create-key-pair --key-name aws-demo-terraform-key --region eu-west-1 --query 'KeyMaterial' --output text | Out-File -Encoding ascii -FilePath "$env:USERPROFILE\.ssh\aws-demo-terraform-key.pem"
   ```

## Configuration

Edit `terraform.tfvars`:

```hcl
aws_region    = "eu-west-1"
project_name  = "aws-demo"
instance_type = "t3.micro"
key_name      = "aws-demo-terraform-key"
db_username   = "postgres"
db_password   = "YourSecurePassword123!"  # Change in production!
```

## Deployment

### 1. Initialize Terraform

```powershell
terraform init
```

### 2. Validate Configuration

```powershell
terraform validate
```

### 3. Preview Changes

```powershell
terraform plan
```

Expected: ~15 resources to create

### 4. Apply

```powershell
terraform apply
```

Duration: ~20-25 minutes (CloudFront distribution takes 15-20 minutes)

### 5. Get Outputs

```powershell
terraform output
```

Key outputs:
- `application_url` - Frontend URL (https://xxxxx.cloudfront.net)
- `api_url` - Backend API URL for frontend configuration
- `s3_bucket_name` - S3 bucket for frontend files
- `cloudfront_distribution_id` - For cache invalidation

## Deploy Frontend to S3

### 1. Get Required Values

```powershell
$S3_BUCKET = terraform output -raw s3_bucket_name
$API_URL = terraform output -raw api_url
$CF_DIST_ID = terraform output -raw cloudfront_distribution_id
```

### 2. Update Frontend Configuration

Navigate to frontend directory and update API URL:

```powershell
cd <frontend-directory>
```

Update `src/config.js` or `.env`:
```javascript
export const API_BASE_URL = '<API_URL>';
```

Or in `.env`:
```
REACT_APP_API_URL=http://aws-demo-alb-xxxxx.eu-west-1.elb.amazonaws.com
```

### 3. Build Frontend

```powershell
npm install
npm run build
```

### 4. Upload to S3

```powershell
aws s3 sync build/ s3://$S3_BUCKET/ --delete
```

### 5. Invalidate CloudFront Cache

```powershell
aws cloudfront create-invalidation --distribution-id $CF_DIST_ID --paths "/*"
```

Wait ~5-10 minutes for invalidation to complete.

## Testing

### Test Frontend

```powershell
$APP_URL = terraform output -raw application_url
Start-Process $APP_URL
```

### Test Backend API

```powershell
$API_URL = terraform output -raw api_url
curl "$API_URL/api/messages"
```

### Check CloudFront Status

```powershell
$CF_DIST_ID = terraform output -raw cloudfront_distribution_id
aws cloudfront get-distribution --id $CF_DIST_ID --query 'Distribution.Status'
```

Should show: "Deployed"

### SSH to Backend Instance

```powershell
$BACKEND_IP = terraform output -raw backend_public_ip
ssh -i "$env:USERPROFILE\.ssh\aws-demo-terraform-key.pem" ec2-user@$BACKEND_IP
```

## Updating Application

### Update Backend

```powershell
# Rebuild and push new image
cd <backend-directory>
docker build -t aws-demo-backend .
docker tag aws-demo-backend:latest <ECR_BACKEND_URL>:latest
docker push <ECR_BACKEND_URL>:latest

# SSH to backend instance and restart
$BACKEND_IP = terraform output -raw backend_public_ip
ssh -i "$env:USERPROFILE\.ssh\aws-demo-terraform-key.pem" ec2-user@$BACKEND_IP

# On the instance:
sudo docker pull <ECR_BACKEND_URL>:latest
sudo docker stop backend-app
sudo docker rm backend-app
sudo docker run -d --name backend-app --restart always -p 8080:8080 \
  -e DATABASE_URL=<db_url> -e DATABASE_USER=<user> -e DATABASE_PASSWORD=<pass> \
  <ECR_BACKEND_URL>:latest
```

### Update Frontend

```powershell
# Navigate to frontend directory
cd <frontend-directory>

# Make your changes, then rebuild
npm run build

# Get S3 bucket name and CloudFront ID
cd <infrastructure-directory>
$S3_BUCKET = terraform output -raw s3_bucket_name
$CF_DIST_ID = terraform output -raw cloudfront_distribution_id

# Upload to S3
aws s3 sync build/ s3://$S3_BUCKET/ --delete

# Invalidate CloudFront cache
aws cloudfront create-invalidation --distribution-id $CF_DIST_ID --paths "/*"
```

## Troubleshooting

### CloudFront Not Deployed Yet

Check status:
```powershell
$CF_DIST_ID = terraform output -raw cloudfront_distribution_id
aws cloudfront get-distribution --id $CF_DIST_ID --query 'Distribution.Status'
```

If "InProgress", wait 15-20 minutes.

### Frontend Shows 404

1. Check if files are in S3:
   ```powershell
   $S3_BUCKET = terraform output -raw s3_bucket_name
   aws s3 ls s3://$S3_BUCKET/ --recursive
   ```

2. Ensure `index.html` exists in root

3. Invalidate CloudFront cache:
   ```powershell
   $CF_DIST_ID = terraform output -raw cloudfront_distribution_id
   aws cloudfront create-invalidation --distribution-id $CF_DIST_ID --paths "/*"
   ```

### API Calls Failing

1. Check CORS configuration in backend
2. Verify API URL in frontend configuration
3. Check backend EC2 health:
   ```powershell
   $BACKEND_ID = terraform output -raw backend_instance_id
   aws ec2 describe-instance-status --instance-ids $BACKEND_ID --region eu-west-1
   ```

### S3 Access Denied

Verify bucket policy allows CloudFront OAI access:
```powershell
$S3_BUCKET = terraform output -raw s3_bucket_name
aws s3api get-bucket-policy --bucket $S3_BUCKET
```

## Cost Estimate

Monthly costs (eu-west-1):
- 1x EC2 t3.micro (backend): ~$7.50
- Application Load Balancer: ~$16.00
- S3 storage (100MB): ~$0.50
- CloudFront (1GB transfer): ~$1.00
- Data transfer: ~$1.00
- **Total: ~$26/month** (RDS and ECR costs are in common infrastructure)

**Savings vs Option A**: ~$6/month (19% reduction)

## Cleanup

### 1. Empty S3 Bucket First

```powershell
$S3_BUCKET = terraform output -raw s3_bucket_name
aws s3 rm s3://$S3_BUCKET/ --recursive
```

### 2. Destroy Infrastructure

```powershell
terraform destroy
```

⚠️ CloudFront distribution deletion takes ~15-20 minutes after terraform destroy completes.

⚠️ Common infrastructure (VPC, RDS, ECR) will remain and must be destroyed separately.
