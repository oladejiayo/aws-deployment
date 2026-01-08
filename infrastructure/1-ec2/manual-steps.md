# EC2 Deployment Guide

## Overview

This option deploys the application on EC2 instances with:
- **Backend**: EC2 instance running Docker container
- **Frontend**: EC2 instance with Nginx serving static files OR S3 + CloudFront
- **Database**: RDS PostgreSQL
- **Load Balancer**: Application Load Balancer (ALB)

## Architecture

### High-Level Overview
```
                    ┌─────────────────┐
                    │   Internet      │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │       ALB       │
                    │   (Port 80/443) │
                    └────────┬────────┘
                             │
            ┌────────────────┼────────────────┐
            │                │                │
   ┌────────▼────────┐      │       ┌────────▼────────┐
   │   EC2 Backend   │      │       │  EC2 Frontend   │
   │   (Port 8080)   │      │       │   (Port 80)     │
   └────────┬────────┘      │       └─────────────────┘
            │               │
   ┌────────▼────────┐      │
   │  RDS PostgreSQL │      │
   │   (Port 5432)   │◄─────┘
   └─────────────────┘
```

### Detailed Architecture with VPC and Security
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                  Internet                                    │
└───────────────────────────────────────┬─────────────────────────────────────┘
                                        │
                              ┌─────────▼──────────┐
                              │  Internet Gateway  │
                              └─────────┬──────────┘
┌─────────────────────────────────────────────────────────────────────────────┐
│  VPC (10.0.0.0/16)                    │                                      │
│                                       │                                      │
│  ┌────────────────────────────────────┼──────────────────────────────────┐  │
│  │  Public Route Table                │                                  │  │
│  │  Destination: 0.0.0.0/0 → Internet Gateway                            │  │
│  └────────────────────────────────────┼──────────────────────────────────┘  │
│                                       │                                      │
│  ┌────────────────────────────────────▼──────────────────────────────────┐  │
│  │                          ALB (aws-demo-alb)                            │  │
│  │                      Security Group: ALB-SG                            │  │
│  │                    Inbound: 80 (0.0.0.0/0), 443 (0.0.0.0/0)           │  │
│  │                                                                        │  │
│  │  Listener Rules:                                                      │  │
│  │  • /api/* → Backend Target Group (port 8080)                         │  │
│  │  • /*     → Frontend Target Group (port 80)                          │  │
│  └────────────┬────────────────────────────────────┬────────────────────┘  │
│               │                                    │                        │
│  ┌────────────┼────────────────────────────────────┼────────────────────┐  │
│  │ eu-west-1a │                                    │ eu-west-1b         │  │
│  │            │                                    │                    │  │
│  │  ┌─────────▼──────────┐              ┌─────────▼──────────┐         │  │
│  │  │ Public Subnet 1    │              │ Public Subnet 2    │         │  │
│  │  │ 10.0.1.0/24        │              │ 10.0.2.0/24        │         │  │
│  │  │                    │              │                    │         │  │
│  │  │ ┌────────────────┐ │              │ ┌────────────────┐ │         │  │
│  │  │ │ EC2 Backend    │ │              │ │ EC2 Frontend   │ │         │  │
│  │  │ │ Docker:8080    │ │              │ │ Nginx:80       │ │         │  │
│  │  │ │ SG: APP-SG     │ │              │ │ SG: APP-SG     │ │         │  │
│  │  │ │ IAM: ECR Access│ │              │ │ IAM: ECR Access│ │         │  │
│  │  │ └────────┬───────┘ │              │ └────────────────┘ │         │  │
│  │  │          │         │              │                    │         │  │
│  │  └──────────┼─────────┘              └────────────────────┘         │  │
│  │             │                                                        │  │
│  │  ┌──────────▼─────────┐              ┌────────────────────┐         │  │
│  │  │ Private Subnet 1   │              │ Private Subnet 2   │         │  │
│  │  │ 10.0.10.0/24       │              │ 10.0.11.0/24       │         │  │
│  │  │                    │              │                    │         │  │
│  │  │ ┌────────────────┐ │              │                    │         │  │
│  │  │ │ RDS PostgreSQL │◄┼──────────────┼────────────────────┘         │  │
│  │  │ │ db.t3.micro    │ │              │                              │  │
│  │  │ │ SG: RDS-SG     │ │              │                              │  │
│  │  │ │ Port: 5432     │ │              │                              │  │
│  │  │ │ Multi-AZ       │ │              │                              │  │
│  │  │ └────────────────┘ │              │                              │  │
│  │  └────────────────────┘              └──────────────────────────────┘  │
│  └─────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                      External Services (AWS Managed)                         │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────┐           │
│  │  Amazon ECR (Elastic Container Registry)                      │           │
│  │  • aws-demo-backend:latest  (Spring Boot JAR in Docker)       │           │
│  │  • aws-demo-frontend:latest (React build + Nginx in Docker)   │           │
│  │                                                                │           │
│  │  EC2 instances pull images via IAM role (no credentials)      │           │
│  └──────────────────────────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────────────────────┘

**Security Group Rules:**

• **ALB-SG**: Allows HTTP (80) and HTTPS (443) from internet (0.0.0.0/0)
• **APP-SG**: Allows 8080 from ALB-SG, 80 from ALB-SG, 22 from anywhere (SSH)
• **RDS-SG**: Allows 5432 from APP-SG only (database isolated from internet)

**Traffic Flow:**
1. User → ALB (port 80/443)
2. ALB → Backend EC2:8080 (for /api/*) OR Frontend EC2:80 (for /*)
3. Backend EC2 → RDS:5432 (database queries)
4. EC2 instances pull Docker images from ECR using IAM role
```

## Cost Estimate (eu-west-1)

| Resource | Type | Monthly Cost |
|----------|------|--------------|
| EC2 Backend | t3.micro | ~$8.50 |
| EC2 Frontend | t3.micro | ~$8.50 |
| RDS PostgreSQL | db.t3.micro | ~$13 |
| ALB | - | ~$16 |
| **Total** | | **~$46/month** |

---

# Manual Deployment Steps

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. EC2 Key Pair created
3. Docker images pushed to ECR (see common setup)

---

## Step 1: Create VPC and Networking

> **Why do we need this?**
> A VPC (Virtual Private Cloud) is your isolated network in AWS. It's like having your own private data center in the cloud where you control IP addresses, subnets, and routing. Without a VPC, your resources can't communicate with each other securely.

### 1.1 Create the VPC

```bash
# Create VPC with a /16 CIDR block (65,536 IP addresses)
# This is the foundation - all other resources will live inside this VPC
aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=aws-demo-vpc}]'

# ⚠️ IMPORTANT: Copy the VpcId from the output and set it as an environment variable
# Example output: "VpcId": "vpc-0123456789abcdef0"
export VPC_ID=vpc-xxxxx
```

### 1.2 Enable DNS Hostnames

```bash
# Enable DNS hostnames so EC2 instances get public DNS names
# Without this, you can't SSH into instances using their public DNS
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames
```

### 1.3 Create Internet Gateway

```bash
# Create an Internet Gateway - this is what allows your VPC to communicate with the internet
# Without this, nothing in your VPC can reach the outside world (or be reached)
aws ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=aws-demo-igw}]'

# ⚠️ IMPORTANT: Copy the InternetGatewayId and export it
export IGW_ID=igw-xxxxx

# Attach the Internet Gateway to your VPC
# An IGW must be attached to a VPC to function
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID
```

### 1.4 Create Public Subnets

> **Why 2 public subnets in different Availability Zones?**
> - **High Availability**: If one AZ goes down, your app still works in the other
> - **ALB Requirement**: Application Load Balancers REQUIRE at least 2 subnets in different AZs
> - **Best Practice**: Always spread resources across AZs for fault tolerance

```bash
# Create Public Subnet 1 in Availability Zone A
# Public subnets are where your EC2 instances (backend/frontend) will live
# They're "public" because they'll have routes to the Internet Gateway
aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone eu-west-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=aws-demo-public-1}]'
export SUBNET_PUBLIC_1=subnet-xxxxx

# Create Public Subnet 2 in Availability Zone B (different AZ for high availability)
aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone eu-west-1b --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=aws-demo-public-2}]'
export SUBNET_PUBLIC_2=subnet-xxxxx

# ⚠️ IMPORTANT: Enable auto-assign public IP for public subnets
# Without this, EC2 instances won't get public IPs and you can't SSH into them!
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_PUBLIC_1 --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_PUBLIC_2 --map-public-ip-on-launch
```

### 1.5 Create Private Subnets (for RDS)

> **Why private subnets for the database?**
> - **Security**: Databases should NEVER be publicly accessible from the internet
> - **Best Practice**: Only your application servers should be able to reach the database
> - **RDS Requirement**: RDS requires a DB Subnet Group with subnets in at least 2 AZs

```bash
# Create Private Subnet 1 - no direct internet access (more secure for databases)
aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.10.0/24 --availability-zone eu-west-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=aws-demo-private-1}]'
export SUBNET_PRIVATE_1=subnet-xxxxx

# Create Private Subnet 2 in different AZ (required for RDS Multi-AZ support)
aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.11.0/24 --availability-zone eu-west-1b --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=aws-demo-private-2}]'
export SUBNET_PRIVATE_2=subnet-xxxxx
```

### 1.6 Create Route Table and Routes

> **Why do we need a route table?**
> Route tables define how network traffic flows. Without proper routes, your EC2 instances can't reach the internet even though you have an Internet Gateway.

```bash
# Create a route table for public subnets
aws ec2 create-route-table --vpc-id $VPC_ID --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=aws-demo-public-rt}]'
export RT_ID=rtb-xxxxx

# Add a route to send all internet-bound traffic (0.0.0.0/0) to the Internet Gateway
# This is what makes a subnet "public" - it has a route to the IGW
aws ec2 create-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID

# Associate public subnets with this route table
# Without this association, subnets use the default route table (no internet access)
aws ec2 associate-route-table --subnet-id $SUBNET_PUBLIC_1 --route-table-id $RT_ID
aws ec2 associate-route-table --subnet-id $SUBNET_PUBLIC_2 --route-table-id $RT_ID

# Note: Private subnets intentionally DON'T get this route table
# They use the default route table which has no internet route
```

---

## Step 2: Create Security Groups

> **Why do we need Security Groups?**
> Security Groups act as virtual firewalls for your AWS resources. They control what traffic is allowed IN (ingress) and OUT (egress). By default, all inbound traffic is blocked and all outbound is allowed.

### 2.1 ALB Security Group

```bash
# Create Security Group for the Application Load Balancer
# This controls what traffic can reach your load balancer from the internet
aws ec2 create-security-group --group-name aws-demo-alb-sg --description "ALB Security Group" --vpc-id $VPC_ID

# ⚠️ IMPORTANT: Copy the GroupId from output
export ALB_SG=sg-xxxxx

# Allow HTTP (port 80) from anywhere - so users can access your website
aws ec2 authorize-security-group-ingress --group-id $ALB_SG --protocol tcp --port 80 --cidr 0.0.0.0/0

# Allow HTTPS (port 443) from anywhere - for secure connections (optional but recommended)
aws ec2 authorize-security-group-ingress --group-id $ALB_SG --protocol tcp --port 443 --cidr 0.0.0.0/0
```

### 2.2 Application Security Group

```bash
# Create Security Group for EC2 instances (backend & frontend)
aws ec2 create-security-group --group-name aws-demo-app-sg --description "App Security Group" --vpc-id $VPC_ID
export APP_SG=sg-xxxxx

# Allow port 8080 ONLY from ALB - backend Spring Boot app listens here
# Using --source-group means only traffic from the ALB security group is allowed (more secure than IP)
aws ec2 authorize-security-group-ingress --group-id $APP_SG --protocol tcp --port 8080 --source-group $ALB_SG

# Allow port 80 ONLY from ALB - frontend Nginx serves on this port
aws ec2 authorize-security-group-ingress --group-id $APP_SG --protocol tcp --port 80 --source-group $ALB_SG

# Allow SSH (port 22) from anywhere - for troubleshooting/maintenance
# ⚠️ SECURITY WARNING: In production, restrict this to your IP only!
aws ec2 authorize-security-group-ingress --group-id $APP_SG --protocol tcp --port 22 --cidr 0.0.0.0/0
```

### 2.3 RDS Security Group

```bash
# Create Security Group for the PostgreSQL database
aws ec2 create-security-group --group-name aws-demo-rds-sg --description "RDS Security Group" --vpc-id $VPC_ID
export RDS_SG=sg-xxxxx

# Allow PostgreSQL (port 5432) ONLY from application instances
# This ensures only your EC2 instances can connect to the database - NOT the internet!
aws ec2 authorize-security-group-ingress --group-id $RDS_SG --protocol tcp --port 5432 --source-group $APP_SG
```

---

## Step 3: Create RDS PostgreSQL Database

> **Why use RDS instead of running PostgreSQL on EC2?**
> - **Managed Service**: AWS handles backups, patching, and maintenance
> - **High Availability**: Easy Multi-AZ failover
> - **Scalability**: Resize with a few clicks
> - **Security**: Automated encryption, network isolation

### 3.1 Create DB Subnet Group

```bash
# RDS requires a DB Subnet Group - tells RDS which subnets it can use
# Must include subnets in at least 2 AZs for failover support
aws rds create-db-subnet-group \
  --db-subnet-group-name aws-demo-db-subnet \
  --db-subnet-group-description "Subnet group for AWS Demo" \
  --subnet-ids $SUBNET_PRIVATE_1 $SUBNET_PRIVATE_2
```

### 3.2 Check Available PostgreSQL Versions

```bash
# List available PostgreSQL versions in your region
# Use one from this list in the next command
aws rds describe-db-engine-versions --engine postgres --query 'DBEngineVersions[*].EngineVersion' --output table
```

### 3.3 Create RDS Instance

```bash
# Create the PostgreSQL database instance
aws rds create-db-instance \
  --db-instance-identifier aws-demo-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 18.1 \
  --master-username postgres \
  --master-user-password YourSecurePassword123 \
  --allocated-storage 20 \
  --db-name awsdemo \
  --vpc-security-group-ids $RDS_SG \
  --db-subnet-group-name aws-demo-db-subnet \
  --no-publicly-accessible

# Explanation of parameters:
# --db-instance-identifier: Unique name for your DB instance
# --db-instance-class: Size of the instance (t3.micro = free tier eligible)
# --engine: Database type (postgres, mysql, etc.)
# --engine-version: Use a version from the list above
# --master-username: Admin username for the database
# --master-user-password: Admin password (use a strong password!)
# --allocated-storage: Disk size in GB
# --db-name: Name of the default database to create
# --vpc-security-group-ids: Which security group to use
# --db-subnet-group-name: Which subnets the DB can use
# --no-publicly-accessible: CRITICAL - keeps DB private!
```

### 3.4 Wait for RDS to be Available

```bash
# RDS takes about 10-15 minutes to create - this command waits until it's ready
# Don't proceed until this completes!
aws rds wait db-instance-available --db-instance-identifier aws-demo-db

# Get the RDS endpoint (hostname) - you'll need this for your application
aws rds describe-db-instances --db-instance-identifier aws-demo-db --query 'DBInstances[0].Endpoint.Address' --output text

# ⚠️ IMPORTANT: Save this endpoint - your backend needs it to connect
export RDS_ENDPOINT=aws-demo-db.xxxxx.eu-west-1.rds.amazonaws.com
```

---

## Step 4: Create EC2 Key Pair

> **Why do we need a key pair?**
> Key pairs are used for secure SSH access to your EC2 instances. AWS stores the public key, you keep the private key. Without this, you can't SSH into your instances for debugging.

```bash
# Generate a new key pair and save the private key to a file
# ⚠️ IMPORTANT: The command differs slightly between shells!

# For Git Bash on Windows (removes Windows line endings):
aws ec2 create-key-pair --key-name aws-demo-key --query 'KeyMaterial' --output text | tr -d '\r' > aws-demo-key.pem

# For PowerShell:
# aws ec2 create-key-pair --key-name aws-demo-key --query 'KeyMaterial' --output text | Out-File -Encoding ascii aws-demo-key.pem

# For Linux/Mac:
# aws ec2 create-key-pair --key-name aws-demo-key --query 'KeyMaterial' --output text > aws-demo-key.pem

# Verify the key looks correct (should show "-----BEGIN RSA PRIVATE KEY-----")
head -1 aws-demo-key.pem

# Set proper permissions on the key file (required for SSH)
chmod 400 aws-demo-key.pem
```

---

## Step 5: Create ECR Repositories and Push Docker Images

> **Why do we need ECR?**
> ECR (Elastic Container Registry) is AWS's Docker image storage service. Your EC2 instances will pull the application images from here. It's like Docker Hub, but private and integrated with AWS.

### 5.1 Create ECR Repositories

```bash
# Create repository for backend Docker image
aws ecr create-repository --repository-name aws-demo-backend --region eu-west-1

# Create repository for frontend Docker image
aws ecr create-repository --repository-name aws-demo-frontend --region eu-west-1

# Get your AWS Account ID (needed for ECR URL)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Account ID: $ACCOUNT_ID"
```

### 5.2 Authenticate Docker to ECR

```bash
# Login to ECR - this allows your local Docker to push images
# The token is valid for 12 hours
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.eu-west-1.amazonaws.com
```

### 5.3 Build and Push Backend Image

```bash
# Navigate to the backend directory (where the Dockerfile is)
cd backend

# Build the Docker image
# -t tags the image with a name
docker build -t aws-demo-backend .

# Tag the image for ECR
# Format: <account-id>.dkr.ecr.<region>.amazonaws.com/<repo-name>:<tag>
docker tag aws-demo-backend:latest ${ACCOUNT_ID}.dkr.ecr.eu-west-1.amazonaws.com/aws-demo-backend:latest

# Push the image to ECR
docker push ${ACCOUNT_ID}.dkr.ecr.eu-west-1.amazonaws.com/aws-demo-backend:latest

# Go back to root directory
cd ..
```

### 5.4 Update Frontend Nginx Config for ALB

> ⚠️ **IMPORTANT**: The default nginx.conf may include a proxy to "backend" for docker-compose.
> With ALB, the load balancer handles API routing, so the frontend nginx should NOT proxy API requests.

Check `frontend/nginx.conf` and ensure it looks like this (no `/api` proxy block):

```nginx
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Serve static files
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Note: API routing is handled by ALB, not nginx
}
```

If there's a `location /api { proxy_pass http://backend:8080; ... }` block, **remove or comment it out**.
This is because the ALB routes `/api/*` requests directly to the backend target group.

### 5.5 Build and Push Frontend Image

```bash
# Navigate to the frontend directory
cd frontend

# Build the Docker image
docker build -t aws-demo-frontend .

# Tag for ECR
docker tag aws-demo-frontend:latest ${ACCOUNT_ID}.dkr.ecr.eu-west-1.amazonaws.com/aws-demo-frontend:latest

# Push to ECR
docker push ${ACCOUNT_ID}.dkr.ecr.eu-west-1.amazonaws.com/aws-demo-frontend:latest

# Go back to root directory
cd ..
```

### 5.6 Verify Images are in ECR

```bash
# List images in backend repository
aws ecr list-images --repository-name aws-demo-backend --region eu-west-1

# List images in frontend repository
aws ecr list-images --repository-name aws-demo-frontend --region eu-west-1
```

---

## Step 6: Create IAM Role for EC2 (ECR Access)

> **Why do we need an IAM role?**
> EC2 instances need permission to pull Docker images from ECR. Instead of storing AWS credentials on the instance (insecure!), we assign an IAM role that grants temporary credentials automatically.

```bash
# Create the trust policy (allows EC2 to assume this role)
cat > ec2-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create the IAM role
aws iam create-role \
  --role-name EC2-ECR-Access \
  --assume-role-policy-document file://ec2-trust-policy.json

# Attach the policy that allows reading from ECR
aws iam attach-role-policy \
  --role-name EC2-ECR-Access \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

# Create an instance profile (required to attach role to EC2)
aws iam create-instance-profile --instance-profile-name EC2-ECR-Access

# Add the role to the instance profile
aws iam add-role-to-instance-profile \
  --instance-profile-name EC2-ECR-Access \
  --role-name EC2-ECR-Access

# Wait a few seconds for IAM to propagate
sleep 10
```

---

## Step 7: Launch Backend EC2 Instance

> **What happens here?**
> We're launching a virtual server that will run our Spring Boot backend inside a Docker container. The "user data" script runs automatically when the instance starts.

### 7.1 Get the Latest Amazon Linux AMI

```bash
# Find the latest Amazon Linux 2023 AMI (Amazon Machine Image)
# AMIs are like "OS templates" - this gets the newest Amazon Linux
AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-*-x86_64" "Name=state,Values=available" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text)

echo "Using AMI: $AMI_ID"
```

### 7.2 Create User Data Script

```bash
# Get your AWS Account ID (needed for ECR URL)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Account ID: $ACCOUNT_ID"

# Create the startup script that runs when EC2 launches
# This script installs Docker and runs our backend container
cat > backend-userdata.sh << EOF
#!/bin/bash
# Update the system
yum update -y

# Install Docker
yum install -y docker

# Start Docker service and enable it to start on boot
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group (allows running docker without sudo)
usermod -a -G docker ec2-user

# Login to ECR (Elastic Container Registry) to pull our image
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.eu-west-1.amazonaws.com

# Pull our backend Docker image from ECR
docker pull ${ACCOUNT_ID}.dkr.ecr.eu-west-1.amazonaws.com/aws-demo-backend:latest

# Run the backend container with environment variables for database connection
docker run -d \
  --name backend \
  --restart always \
  -p 8080:8080 \
  -e DATABASE_URL=jdbc:postgresql://${RDS_ENDPOINT}:5432/awsdemo \
  -e DATABASE_USER=postgres \
  -e DATABASE_PASSWORD=YourSecurePassword123 \
  ${ACCOUNT_ID}.dkr.ecr.eu-west-1.amazonaws.com/aws-demo-backend:latest
  
EOF
```

### 7.3 Launch the Backend Instance

```bash
# Launch the EC2 instance
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.micro \
  --key-name aws-demo-key \
  --security-group-ids $APP_SG \
  --subnet-id $SUBNET_PUBLIC_1 \
  --iam-instance-profile Name=EC2-ECR-Access \
  --user-data file://backend-userdata.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=aws-demo-backend}]'

# Parameters explained:
# --image-id: The OS image to use (Amazon Linux 2023)
# --instance-type: Size of instance (t3.micro = 2 vCPU, 1GB RAM, free tier)
# --key-name: SSH key for access
# --security-group-ids: Firewall rules to apply
# --subnet-id: Which subnet to launch in
# --iam-instance-profile: IAM role for ECR access
# --user-data: Startup script to run
# --tag-specifications: Name tag for easy identification

# ⚠️ IMPORTANT: Copy the InstanceId from the output
export BACKEND_INSTANCE_ID=i-xxxxx
```

---

## Step 8: Launch Frontend EC2 Instance

> **Similar to backend, but for the React/Nginx frontend**

### 8.1 Create Frontend User Data Script

```bash
cat > frontend-userdata.sh << EOF
#!/bin/bash
yum update -y
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Login to ECR
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.eu-west-1.amazonaws.com

# Pull and run frontend (Nginx serving React app)
docker pull ${ACCOUNT_ID}.dkr.ecr.eu-west-1.amazonaws.com/aws-demo-frontend:latest
docker run -d \
  --name frontend \
  --restart always \
  -p 80:80 \
  ${ACCOUNT_ID}.dkr.ecr.eu-west-1.amazonaws.com/aws-demo-frontend:latest
EOF
```

### 8.2 Launch the Frontend Instance

```bash
# Launch in a different subnet (AZ) for high availability
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.micro \
  --key-name aws-demo-key \
  --security-group-ids $APP_SG \
  --subnet-id $SUBNET_PUBLIC_2 \
  --iam-instance-profile Name=EC2-ECR-Access \
  --user-data file://frontend-userdata.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=aws-demo-frontend}]'

# ⚠️ IMPORTANT: Copy the InstanceId
export FRONTEND_INSTANCE_ID=i-xxxxx
```

---

## Step 9: Create Application Load Balancer

> **Why do we need a Load Balancer?**
> - **Single Entry Point**: Users access one URL, ALB routes to the right service
> - **Path-Based Routing**: `/api/*` goes to backend, everything else to frontend
> - **Health Checks**: ALB only sends traffic to healthy instances
> - **High Availability**: Can distribute traffic across multiple instances

### 9.1 Create the ALB

```bash
# Create the Application Load Balancer
aws elbv2 create-load-balancer \
  --name aws-demo-alb \
  --subnets $SUBNET_PUBLIC_1 $SUBNET_PUBLIC_2 \
  --security-groups $ALB_SG \
  --scheme internet-facing \
  --type application

# Parameters:
# --subnets: Must be in at least 2 AZs
# --scheme internet-facing: Accessible from the internet
# --type application: Layer 7 (HTTP/HTTPS) load balancer

# ⚠️ IMPORTANT: Copy the LoadBalancerArn from output
export ALB_ARN=arn:aws:elasticloadbalancing:eu-west-1:xxxx:loadbalancer/app/aws-demo-alb/xxxx
```

### 9.2 Create Target Groups

> **What are Target Groups?**
> Target groups define where the ALB should send traffic. Each group contains instances (targets) that handle the same type of request.

> ⚠️ **Windows Git Bash Users**: Git Bash converts paths starting with `/` to Windows paths.
> Use `//api/messages` (double slash) or run in **PowerShell** or **CMD** instead.

```bash
# Create Backend Target Group (for API requests)
# NOTE: Use //api/messages in Git Bash, or /api/messages in PowerShell/CMD
aws elbv2 create-target-group \
  --name aws-demo-backend-tg \
  --protocol HTTP \
  --port 8080 \
  --vpc-id $VPC_ID \
  --health-check-path //api/messages \
  --target-type instance

# Note: The health check path shows //api/messages - this will still work because most HTTP servers normalize double slashes to single slashes. If you encounter health check failures later, you can update it with:
# --health-check-path: ALB calls this endpoint to check if instance is healthy
# --port 8080: Backend Spring Boot runs on this port

export BACKEND_TG_ARN=arn:aws:elasticloadbalancing:...

# Create Frontend Target Group (for web requests)
aws elbv2 create-target-group \
  --name aws-demo-frontend-tg \
  --protocol HTTP \
  --port 80 \
  --vpc-id $VPC_ID \
  --health-check-path // \
  --target-type instance

export FRONTEND_TG_ARN=arn:aws:elasticloadbalancing:...
```

### 9.3 Register Instances with Target Groups

```bash
# Tell ALB which instances belong to which target group
aws elbv2 register-targets --target-group-arn $BACKEND_TG_ARN --targets Id=$BACKEND_INSTANCE_ID
aws elbv2 register-targets --target-group-arn $FRONTEND_TG_ARN --targets Id=$FRONTEND_INSTANCE_ID
```

### 9.4 Create Listener and Rules

> **What is a Listener?**
> A listener checks for connection requests on a specific port (80 for HTTP) and routes them according to rules.

```bash
# Create the main listener on port 80
# Default action: send to frontend (for serving the React app)
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$FRONTEND_TG_ARN

# ⚠️ IMPORTANT: Copy the ListenerArn from output
export LISTENER_ARN=arn:aws:elasticloadbalancing:...

# Add a rule to route /api/* requests to the backend
# This enables our frontend to call the backend API through the same domain
aws elbv2 create-rule \
  --listener-arn $LISTENER_ARN \
  --priority 10 \
  --conditions Field=path-pattern,Values='/api/*' \
  --actions Type=forward,TargetGroupArn=$BACKEND_TG_ARN
```

---

## Step 10: Test the Deployment

```bash
# Get the ALB DNS name - this is your application's URL!
ALB_DNS=$(aws elbv2 describe-load-balancers --names aws-demo-alb --query 'LoadBalancers[0].DNSName' --output text)
echo "Your application URL: http://$ALB_DNS"

# Wait a few minutes for instances to pass health checks, then test:

# Test frontend (should return HTML)
curl http://$ALB_DNS/

# Test backend API (should return JSON)
curl http://$ALB_DNS/api/messages

# Test creating a message
curl -X POST http://$ALB_DNS/api/messages \
  -H "Content-Type: application/json" \
  -d '{"content": "Hello from EC2!"}'
```

---

## Troubleshooting

### Check EC2 Instance Status

```bash
# View instance status
aws ec2 describe-instance-status --instance-ids $BACKEND_INSTANCE_ID $FRONTEND_INSTANCE_ID

# SSH into backend to check logs
ssh -i aws-demo-key.pem ec2-user@<BACKEND_PUBLIC_IP>
sudo docker logs backend
```

### Check Target Group Health

```bash
# See if instances are healthy in the target group
aws elbv2 describe-target-health --target-group-arn $BACKEND_TG_ARN
aws elbv2 describe-target-health --target-group-arn $FRONTEND_TG_ARN
```

### Check RDS Connectivity

```bash
# From the backend EC2 instance, test database connection
ssh -i aws-demo-key.pem ec2-user@<BACKEND_PUBLIC_IP>
sudo docker exec -it backend sh
# Inside container, check if you can reach RDS
nc -zv $RDS_ENDPOINT 5432
```

---

# Cleanup

> **⚠️ IMPORTANT: Delete resources to avoid ongoing charges!**
> Delete in this order to avoid dependency errors.

```bash
# 1. Delete ALB and Target Groups
aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN
# Wait for ALB to delete
sleep 60
aws elbv2 delete-target-group --target-group-arn $BACKEND_TG_ARN
aws elbv2 delete-target-group --target-group-arn $FRONTEND_TG_ARN

# 2. Terminate EC2 instances
aws ec2 terminate-instances --instance-ids $BACKEND_INSTANCE_ID $FRONTEND_INSTANCE_ID
# Wait for instances to terminate
aws ec2 wait instance-terminated --instance-ids $BACKEND_INSTANCE_ID $FRONTEND_INSTANCE_ID

# 3. Delete RDS (takes a few minutes)
aws rds delete-db-instance --db-instance-identifier aws-demo-db --skip-final-snapshot
aws rds wait db-instance-deleted --db-instance-identifier aws-demo-db

# 4. Delete DB Subnet Group
aws rds delete-db-subnet-group --db-subnet-group-name aws-demo-db-subnet

# 5. Delete Security Groups (must delete in correct order due to dependencies)
aws ec2 delete-security-group --group-id $RDS_SG
aws ec2 delete-security-group --group-id $APP_SG
aws ec2 delete-security-group --group-id $ALB_SG

# 6. Delete Subnets
aws ec2 delete-subnet --subnet-id $SUBNET_PRIVATE_1
aws ec2 delete-subnet --subnet-id $SUBNET_PRIVATE_2
aws ec2 delete-subnet --subnet-id $SUBNET_PUBLIC_1
aws ec2 delete-subnet --subnet-id $SUBNET_PUBLIC_2

# 7. Delete Route Table
aws ec2 delete-route-table --route-table-id $RT_ID

# 8. Detach and Delete Internet Gateway
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID

# 9. Delete VPC
aws ec2 delete-vpc --vpc-id $VPC_ID

# 10. Delete IAM Role (optional - can reuse)
aws iam remove-role-from-instance-profile --instance-profile-name EC2-ECR-Access --role-name EC2-ECR-Access
aws iam delete-instance-profile --instance-profile-name EC2-ECR-Access
aws iam detach-role-policy --role-name EC2-ECR-Access --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
aws iam delete-role --role-name EC2-ECR-Access

# 11. Delete Key Pair
aws ec2 delete-key-pair --key-name aws-demo-key
rm aws-demo-key.pem

# 12. Delete ECR Repositories (and all images inside)
aws ecr delete-repository --repository-name aws-demo-backend --force
aws ecr delete-repository --repository-name aws-demo-frontend --force
```

---

## Summary

You've just deployed:
1. ✅ **VPC** - Your private network in AWS
2. ✅ **Subnets** - Public (for EC2) and Private (for RDS)
3. ✅ **Security Groups** - Firewall rules for each component
4. ✅ **RDS PostgreSQL** - Managed database in private subnet
5. ✅ **EC2 Instances** - Backend (Spring Boot) and Frontend (React/Nginx)
6. ✅ **Application Load Balancer** - Routes traffic to the right service

This is the **most manual** deployment option, but gives you **complete control** over every component!
