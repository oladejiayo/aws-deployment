# Option A: EC2 for Both Frontend and Backend

This Terraform configuration deploys both the frontend and backend on separate EC2 instances with an Application Load Balancer.

## Architecture

```
Internet
   |
   v
Application Load Balancer
   |
   +-- Frontend (EC2) - Port 80
   |
   +-- Backend (EC2) - Port 8080
         |
         v
      RDS PostgreSQL
```

## Resources Created

- **2 EC2 Instances**: One for frontend, one for backend
- **Application Load Balancer**: Routes traffic to frontend and backend
- **2 Target Groups**: One for each EC2 instance
- **IAM Role**: For EC2 instances to access ECR
- **Security Groups**: Inherited from common infrastructure

## Prerequisites

1. Deploy common infrastructure first:
   ```powershell
   cd ..\..\..\common\terraform
   terraform apply
   ```

2. Build and push Docker images to ECR:
   ```powershell
   # Get ECR URLs from common infrastructure
   cd ..\..\..\common\terraform
   terraform output ecr_backend_url
   terraform output ecr_frontend_url
   
   # Authenticate Docker to ECR
   aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.eu-west-1.amazonaws.com
   
   # Build and push backend
   cd ..\..\..\..\..\backend
   docker build -t aws-demo-backend .
   docker tag aws-demo-backend:latest <ECR_BACKEND_URL>:latest
   docker push <ECR_BACKEND_URL>:latest
   
   # Build and push frontend
   cd ..\frontend
   docker build -t aws-demo-frontend .
   docker tag aws-demo-frontend:latest <ECR_FRONTEND_URL>:latest
   docker push <ECR_FRONTEND_URL>:latest
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

Expected: ~13 resources to create

### 4. Apply

```powershell
terraform apply
```

Duration: ~5-10 minutes

### 5. Get Outputs

```powershell
terraform output
```

Key outputs:
- `application_url` - Your application URL (http://alb-dns-name)
- `backend_instance_id` - Backend EC2 instance ID
- `frontend_instance_id` - Frontend EC2 instance ID

## Testing

### Test Frontend

```powershell
$APP_URL = terraform output -raw application_url
Start-Process $APP_URL
```

### Test Backend API

```powershell
$ALB_DNS = terraform output -raw alb_dns_name
curl "http://$ALB_DNS/api/messages"
```

### SSH to Instances

```powershell
# Backend
$BACKEND_IP = terraform output -raw backend_public_ip
ssh -i "$env:USERPROFILE\.ssh\aws-demo-terraform-key.pem" ec2-user@$BACKEND_IP

# Frontend
$FRONTEND_IP = terraform output -raw frontend_public_ip
ssh -i "$env:USERPROFILE\.ssh\aws-demo-terraform-key.pem" ec2-user@$FRONTEND_IP
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
# Rebuild and push new image
cd <frontend-directory>
docker build -t aws-demo-frontend .
docker tag aws-demo-frontend:latest <ECR_FRONTEND_URL>:latest
docker push <ECR_FRONTEND_URL>:latest

# SSH to frontend instance and restart
$FRONTEND_IP = terraform output -raw frontend_public_ip
ssh -i "$env:USERPROFILE\.ssh\aws-demo-terraform-key.pem" ec2-user@$FRONTEND_IP

# On the instance:
sudo docker pull <ECR_FRONTEND_URL>:latest
sudo docker stop frontend-app
sudo docker rm frontend-app
sudo docker run -d --name frontend-app --restart always -p 80:80 <ECR_FRONTEND_URL>:latest
```

## Troubleshooting

### Check EC2 Instance Status

```powershell
$BACKEND_ID = terraform output -raw backend_instance_id
$FRONTEND_ID = terraform output -raw frontend_instance_id

aws ec2 describe-instances --instance-ids $BACKEND_ID $FRONTEND_ID --region eu-west-1
```

### Check Docker Containers

```powershell
# SSH to instance first
sudo docker ps
sudo docker logs backend-app
sudo docker logs frontend-app
```

### Check ALB Health

```powershell
# Get target group ARN from AWS console or CLI
aws elbv2 describe-target-health --target-group-arn <arn> --region eu-west-1
```

## Cost Estimate

Monthly costs (eu-west-1):
- 2x EC2 t3.micro: ~$15.00
- Application Load Balancer: ~$16.00
- Data transfer: ~$1.00
- **Total: ~$32/month** (RDS and ECR costs are in common infrastructure)

## Cleanup

```powershell
terraform destroy
```

⚠️ This will delete all resources created by this configuration. Common infrastructure (VPC, RDS, ECR) will remain.
