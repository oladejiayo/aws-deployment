# push-to-ecr.ps1 - PowerShell script to build and push Docker images to ECR

param(
    [string]$Region = "us-east-1",
    [string]$ProjectName = "aws-demo"
)

$ErrorActionPreference = "Stop"

# Get AWS account ID
$AwsAccountId = aws sts get-caller-identity --query Account --output text

Write-Host "AWS Account: $AwsAccountId" -ForegroundColor Yellow
Write-Host "AWS Region: $Region" -ForegroundColor Yellow
Write-Host "Project: $ProjectName" -ForegroundColor Yellow

# Login to ECR
Write-Host "Logging into ECR..." -ForegroundColor Green
$password = aws ecr get-login-password --region $Region
$password | docker login --username AWS --password-stdin "$AwsAccountId.dkr.ecr.$Region.amazonaws.com"

# Build and push backend
Write-Host "Building backend image..." -ForegroundColor Green
docker build -t "$ProjectName-backend" ../backend

Write-Host "Tagging backend image..." -ForegroundColor Green
docker tag "${ProjectName}-backend:latest" "$AwsAccountId.dkr.ecr.$Region.amazonaws.com/$ProjectName-backend:latest"

Write-Host "Pushing backend image..." -ForegroundColor Green
docker push "$AwsAccountId.dkr.ecr.$Region.amazonaws.com/$ProjectName-backend:latest"

# Build and push frontend
Write-Host "Building frontend image..." -ForegroundColor Green
docker build -t "$ProjectName-frontend" ../frontend

Write-Host "Tagging frontend image..." -ForegroundColor Green
docker tag "${ProjectName}-frontend:latest" "$AwsAccountId.dkr.ecr.$Region.amazonaws.com/$ProjectName-frontend:latest"

Write-Host "Pushing frontend image..." -ForegroundColor Green
docker push "$AwsAccountId.dkr.ecr.$Region.amazonaws.com/$ProjectName-frontend:latest"

Write-Host "Done! Images pushed to ECR:" -ForegroundColor Green
Write-Host "  - $AwsAccountId.dkr.ecr.$Region.amazonaws.com/$ProjectName-backend:latest"
Write-Host "  - $AwsAccountId.dkr.ecr.$Region.amazonaws.com/$ProjectName-frontend:latest"
