# EC2 Deployment Guide

## Overview

This option deploys the application on EC2 instances with:
- **Backend**: EC2 instance running Docker container
- **Frontend**: **Choose one of two options:**
  - **Option A**: EC2 instance with Nginx serving static files (simpler, all in EC2)
  - **Option B**: S3 + CloudFront (serverless frontend, better performance, lower cost)
- **Database**: RDS PostgreSQL
- **Load Balancer**: Application Load Balancer (ALB)

### Which Frontend Option Should You Choose?

| Criteria | EC2 + Nginx | S3 + CloudFront |
|----------|-------------|------------------|
| **Cost** | ~$8.50/month | ~$1-2/month |
| **Performance** | Good | Excellent (global CDN) |
| **Scalability** | Limited to instance size | Auto-scales globally |
| **Maintenance** | Manage EC2 instance | Fully managed |
| **Setup Complexity** | Simpler | Slightly more steps |
| **Best For** | Learning EC2, simple apps | Production, global users |

**Recommendation**: Use **S3 + CloudFront** for production workloads. Use **EC2 + Nginx** for learning or if you need custom server-side logic.

## Architecture

### High-Level Overview - Option A: EC2 Frontend

```mermaid
graph TB
    Internet[🌐 Internet]
    ALB[⚖️ Application Load Balancer<br/>Port 80/443]
    Backend[🖥️ EC2 Backend<br/>Spring Boot:8080]
    Frontend[🖥️ EC2 Frontend<br/>Nginx:80]
    RDS[(🗄️ RDS PostgreSQL<br/>Port 5432)]
    
    Internet --> ALB
    ALB -->|/api/*| Backend
    ALB -->|/*| Frontend
    Backend --> RDS
    
    style Internet fill:#e1f5ff
    style ALB fill:#fff4e1
    style Backend fill:#e8f5e9
    style Frontend fill:#e8f5e9
    style RDS fill:#f3e5f5
```

### High-Level Overview - Option B: S3 + CloudFront Frontend

```mermaid
graph TB
    Internet[🌐 Internet]
    CF[☁️ CloudFront CDN<br/>Global Edge Locations]
    S3[🪣 S3 Bucket<br/>Static Files]
    ALB[⚖️ Application Load Balancer<br/>Port 80/443]
    Backend[🖥️ EC2 Backend<br/>Spring Boot:8080]
    RDS[(🗄️ RDS PostgreSQL<br/>Port 5432)]
    
    Internet -->|HTML/JS/CSS| CF
    CF --> S3
    Internet -->|/api/*| ALB
    ALB --> Backend
    Backend --> RDS
    
    style Internet fill:#e1f5ff
    style CF fill:#fff4e1
    style S3 fill:#e8f5e9
    style ALB fill:#fff4e1
    style Backend fill:#e8f5e9
    style RDS fill:#f3e5f5
```

### Detailed Architecture - Option A: EC2 Frontend

```mermaid
graph TB
    subgraph Internet
        Users[👥 Users]
    end
    
    IGW[🌐 Internet Gateway]
    
    subgraph VPC["🏢 VPC (10.0.0.0/16)"]
        subgraph PublicRT["📋 Public Route Table<br/>(0.0.0.0/0 → IGW)"]
        end
        
        ALB[⚖️ ALB<br/>Security Group: ALB-SG<br/>Inbound: 80, 443 from 0.0.0.0/0]
        
        subgraph AZ1["🏗️ Availability Zone: eu-west-1a"]
            subgraph PubSub1["Public Subnet<br/>10.0.1.0/24"]
                Backend[🖥️ EC2 Backend<br/>Docker:8080<br/>SG: APP-SG<br/>IAM: ECR Access]
            end
            
            subgraph PrivSub1["🔒 Private Subnet<br/>10.0.10.0/24"]
                RDS1[(🗄️ RDS PostgreSQL<br/>db.t3.micro<br/>SG: RDS-SG<br/>Port: 5432)]
            end
        end
        
        subgraph AZ2["🏗️ Availability Zone: eu-west-1b"]
            subgraph PubSub2["Public Subnet<br/>10.0.2.0/24"]
                Frontend[🖥️ EC2 Frontend<br/>Nginx:80<br/>SG: APP-SG<br/>IAM: ECR Access]
            end
            
            subgraph PrivSub2["🔒 Private Subnet<br/>10.0.11.0/24"]
                RDS2[(Standby)]
            end
        end
    end
    
    subgraph External["☁️ AWS Managed Services"]
        ECR[📦 Amazon ECR<br/>• backend:latest<br/>• frontend:latest]
    end
    
    Users --> IGW
    IGW --> ALB
    ALB -->|Target Group<br/>Port 8080| Backend
    ALB -->|Target Group<br/>Port 80| Frontend
    Backend --> RDS1
    RDS1 -.->|Multi-AZ<br/>Replication| RDS2
    Backend -.->|Pull Image| ECR
    Frontend -.->|Pull Image| ECR
    
    style VPC fill:#e3f2fd
    style AZ1 fill:#fff3e0
    style AZ2 fill:#fff3e0
    style PubSub1 fill:#c8e6c9
    style PubSub2 fill:#c8e6c9
    style PrivSub1 fill:#ffcdd2
    style PrivSub2 fill:#ffcdd2
    style External fill:#f3e5f5
```

### Detailed Architecture - Option B: S3 + CloudFront Frontend

```mermaid
graph TB
    subgraph Internet
        Users[👥 Users]
    end
    
    subgraph Global["🌍 Global AWS Services"]
        CF[☁️ CloudFront<br/>Distribution<br/>Edge Locations Worldwide]
        S3[🪣 S3 Bucket<br/>Origin<br/>• index.html<br/>• assets/*.js<br/>• assets/*.css]
    end
    
    IGW[🌐 Internet Gateway]
    
    subgraph VPC["🏢 VPC (10.0.0.0/16)"]
        ALB[⚖️ ALB<br/>Security Group: ALB-SG<br/>Inbound: 80, 443 from 0.0.0.0/0]
        
        subgraph AZ1["🏗️ Availability Zone: eu-west-1a"]
            subgraph PubSub1["Public Subnet<br/>10.0.1.0/24"]
                Backend[🖥️ EC2 Backend<br/>Docker:8080<br/>SG: APP-SG<br/>IAM: ECR Access]
            end
            
            subgraph PrivSub1["🔒 Private Subnet<br/>10.0.10.0/24"]
                RDS1[(🗄️ RDS PostgreSQL<br/>db.t3.micro<br/>SG: RDS-SG<br/>Port: 5432)]
            end
        end
        
        subgraph AZ2["🏗️ Availability Zone: eu-west-1b"]
            subgraph PrivSub2["🔒 Private Subnet<br/>10.0.11.0/24"]
                RDS2[(Standby)]
            end
        end
    end
    
    subgraph External["☁️ AWS Managed Services"]
        ECR[📦 Amazon ECR<br/>• backend:latest]
    end
    
    Users -->|HTML/JS/CSS| CF
    CF --> S3
    Users -->|/api/*| IGW
    IGW --> ALB
    ALB -->|Target Group<br/>Port 8080| Backend
    Backend --> RDS1
    RDS1 -.->|Multi-AZ<br/>Replication| RDS2
    Backend -.->|Pull Image| ECR
    
    style VPC fill:#e3f2fd
    style AZ1 fill:#fff3e0
    style AZ2 fill:#fff3e0
    style PubSub1 fill:#c8e6c9
    style PrivSub1 fill:#ffcdd2
    style PrivSub2 fill:#ffcdd2
    style Global fill:#fff4e1
    style External fill:#f3e5f5
```

### Security Group Rules

```mermaid
graph LR
    Internet[🌐 Internet<br/>0.0.0.0/0]
    
    subgraph ALB_SG["🛡️ ALB-SG"]
        ALB[ALB]
    end
    
    subgraph APP_SG["🛡️ APP-SG"]
        EC2[EC2 Instances]
    end
    
    subgraph RDS_SG["🛡️ RDS-SG"]
        RDS[(RDS)]
    end
    
    Internet -->|80, 443| ALB
    ALB -->|8080, 80| EC2
    EC2 -->|5432| RDS
    Internet -.->|22 SSH| EC2
    
    style ALB_SG fill:#fff4e1
    style APP_SG fill:#e8f5e9
    style RDS_SG fill:#f3e5f5
```

### Traffic Flow

```mermaid
sequenceDiagram
    participant User
    participant ALB
    participant Backend
    participant Frontend
    participant RDS
    participant ECR
    
    Note over User,RDS: Initial Setup
    Backend->>ECR: Pull backend:latest image
    Frontend->>ECR: Pull frontend:latest image
    
    Note over User,RDS: Frontend Request
    User->>ALB: GET / (Port 80)
    ALB->>Frontend: Route to Frontend:80
    Frontend-->>User: Return HTML/JS/CSS
    
    Note over User,RDS: API Request
    User->>ALB: GET /api/messages
    ALB->>Backend: Route to Backend:8080
    Backend->>RDS: Query database:5432
    RDS-->>Backend: Return data
    Backend-->>ALB: JSON response
    ALB-->>User: Return JSON
```

**Key Components:**

• **VPC**: Isolated network (10.0.0.0/16) with public and private subnets across 2 AZs
• **ALB**: Routes `/api/*` to backend, everything else to frontend
• **EC2 Instances**: Pull Docker images from ECR using IAM roles
• **RDS**: PostgreSQL in private subnets, only accessible from APP-SG
• **Security**: Multi-layered security groups control all traffic

**Key Components:**

• **VPC**: Isolated network (10.0.0.0/16) with public and private subnets across 2 AZs
• **ALB**: Routes `/api/*` to backend, everything else to frontend
• **EC2 Instances**: Pull Docker images from ECR using IAM roles
• **RDS**: PostgreSQL in private subnets, only accessible from APP-SG
• **Security**: Multi-layered security groups control all traffic

**Security Group Rules:**

• **ALB-SG**: Allows HTTP (80) and HTTPS (443) from internet (0.0.0.0/0)
• **APP-SG**: Allows 8080 from ALB-SG, 80 from ALB-SG, 22 from anywhere (SSH)
• **RDS-SG**: Allows 5432 from APP-SG only (database isolated from internet)

**Traffic Flow:**
1. User → ALB (port 80/443)
2. ALB → Backend EC2:8080 (for /api/*) OR Frontend EC2:80 (for /*)
3. Backend EC2 → RDS:5432 (database queries)
4. EC2 instances pull Docker images from ECR using IAM role

## Cost Estimate (eu-west-1)

### Option A: EC2 Frontend

| Resource | Type | Monthly Cost |
|----------|------|--------------||
| EC2 Backend | t3.micro | ~$8.50 |
| EC2 Frontend | t3.micro | ~$8.50 |
| RDS PostgreSQL | db.t3.micro | ~$13 |
| ALB | - | ~$16 |
| **Total** | | **~$46/month** |

### Option B: S3 + CloudFront Frontend

| Resource | Type | Monthly Cost |
|----------|------|--------------||
| EC2 Backend | t3.micro | ~$8.50 |
| S3 Storage | Standard | ~$0.50 (for 20GB) |
| S3 Requests | GET/PUT | ~$0.05 (10k requests) |
| CloudFront | Data Transfer | ~$1.00 (10GB out) |
| RDS PostgreSQL | db.t3.micro | ~$13 |
| ALB | - | ~$16 |
| **Total** | | **~$39/month** |

💰 **Savings**: ~$7/month (~15%) by using S3 + CloudFront instead of EC2 for frontend

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

## Step 8: Deploy Frontend

> **Choose ONE of the two options below:**
> - **Option A**: EC2 with Nginx (simpler, all-in-EC2 architecture)
> - **Option B**: S3 + CloudFront (recommended for production)

---

### Option A: EC2 Frontend Deployment

> **Similar to backend, but for the React/Nginx frontend**

#### 8A.1 Create Frontend User Data Script

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

#### 8A.2 Launch the Frontend Instance

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

**✅ If you chose Option A, skip to [Step 9: Create Application Load Balancer](#step-9-create-application-load-balancer)**

---

### Option B: S3 + CloudFront Frontend Deployment

> **Why S3 + CloudFront?**
> - **Cost**: ~$1-2/month vs $8.50/month for EC2
> - **Performance**: Global CDN with edge caching
> - **Scalability**: Handles traffic spikes automatically
> - **Reliability**: 99.99% uptime SLA
> - **No Server Management**: Fully managed by AWS

#### 8B.1 Build the Frontend

```bash
# Navigate to frontend directory
cd ../../frontend

# Update the API URL to point to the ALB (we'll update this after creating ALB)
# For now, we'll use a placeholder and update it later
cat > .env.production << 'EOF'
VITE_API_URL=http://PLACEHOLDER-ALB-URL
EOF

# Install dependencies and build
npm install
npm run build

# The build output is in frontend/dist/
ls -la dist/
```

#### 8B.2 Create S3 Bucket for Static Hosting

```bash
# Navigate back to infrastructure directory
cd ../infrastructure/1-ec2

# Create a unique bucket name (S3 bucket names must be globally unique)
BUCKET_NAME="aws-demo-frontend-$(date +%s)"
echo "Bucket name: $BUCKET_NAME"
export BUCKET_NAME

# Create the S3 bucket
aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region eu-west-1 \
  --create-bucket-configuration LocationConstraint=eu-west-1

# Block public access at the bucket level (CloudFront will access via OAI)
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=false,RestrictPublicBuckets=false"

# Enable versioning (best practice for production)
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled
```

#### 8B.3 Upload Frontend Files to S3

```bash
# Sync the built frontend to S3
aws s3 sync ../../frontend/dist/ s3://$BUCKET_NAME/ \
  --delete \
  --cache-control "public, max-age=31536000" \
  --exclude "index.html"

# Upload index.html separately with no-cache (so users always get latest version)
aws s3 cp ../../frontend/dist/index.html s3://$BUCKET_NAME/index.html \
  --cache-control "no-cache, no-store, must-revalidate"

# Verify files were uploaded
aws s3 ls s3://$BUCKET_NAME/ --recursive
```

#### 8B.4 Create CloudFront Origin Access Identity (OAI)

> **What is OAI?**
> Origin Access Identity allows CloudFront to access S3 bucket contents without making the bucket public. Only CloudFront can read the files, not direct internet access.

```bash
# Create OAI
OAI_OUTPUT=$(aws cloudfront create-cloud-front-origin-access-identity \
  --cloud-front-origin-access-identity-config \
    CallerReference="aws-demo-frontend-$(date +%s)",Comment="OAI for aws-demo frontend")

# Extract the OAI ID
OAI_ID=$(echo $OAI_OUTPUT | jq -r '.CloudFrontOriginAccessIdentity.Id')
echo "OAI ID: $OAI_ID"
export OAI_ID

# Get the S3 Canonical User ID (needed for bucket policy)
OAI_S3_CANONICAL_USER=$(echo $OAI_OUTPUT | jq -r '.CloudFrontOriginAccessIdentity.S3CanonicalUserId')
export OAI_S3_CANONICAL_USER
```

#### 8B.5 Update S3 Bucket Policy for CloudFront

```bash
# Create bucket policy that grants CloudFront read access
cat > s3-bucket-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontOAI",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity $OAI_ID"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
    }
  ]
}
EOF

# Apply the bucket policy
aws s3api put-bucket-policy \
  --bucket $BUCKET_NAME \
  --policy file://s3-bucket-policy.json
```

#### 8B.6 Create CloudFront Distribution

> **What is CloudFront?**
> AWS's Content Delivery Network (CDN) that caches your frontend files at edge locations worldwide for fast, low-latency access.

```bash
# Create CloudFront distribution configuration
cat > cloudfront-config.json << EOF
{
  "CallerReference": "aws-demo-frontend-$(date +%s)",
  "Comment": "aws-demo frontend distribution",
  "Enabled": true,
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "S3-$BUCKET_NAME",
        "DomainName": "$BUCKET_NAME.s3.eu-west-1.amazonaws.com",
        "S3OriginConfig": {
          "OriginAccessIdentity": "origin-access-identity/cloudfront/$OAI_ID"
        }
      }
    ]
  },
  "DefaultRootObject": "index.html",
  "DefaultCacheBehavior": {
    "TargetOriginId": "S3-$BUCKET_NAME",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["GET", "HEAD"]
      }
    },
    "Compress": true,
    "ForwardedValues": {
      "QueryString": false,
      "Cookies": {
        "Forward": "none"
      }
    },
    "MinTTL": 0,
    "DefaultTTL": 86400,
    "MaxTTL": 31536000,
    "TrustedSigners": {
      "Enabled": false,
      "Quantity": 0
    }
  },
  "CustomErrorResponses": {
    "Quantity": 1,
    "Items": [
      {
        "ErrorCode": 404,
        "ResponsePagePath": "/index.html",
        "ResponseCode": "200",
        "ErrorCachingMinTTL": 300
      }
    ]
  },
  "PriceClass": "PriceClass_100",
  "ViewerCertificate": {
    "CloudFrontDefaultCertificate": true
  }
}
EOF

# Create the distribution (this takes 15-20 minutes to deploy globally)
CF_OUTPUT=$(aws cloudfront create-distribution --distribution-config file://cloudfront-config.json)

# Extract CloudFront domain name
CLOUDFRONT_DOMAIN=$(echo $CF_OUTPUT | jq -r '.Distribution.DomainName')
echo "CloudFront Domain: $CLOUDFRONT_DOMAIN"
export CLOUDFRONT_DOMAIN

# Extract distribution ID (needed for invalidations later)
CF_DISTRIBUTION_ID=$(echo $CF_OUTPUT | jq -r '.Distribution.Id')
echo "Distribution ID: $CF_DISTRIBUTION_ID"
export CF_DISTRIBUTION_ID

echo "⏳ CloudFront distribution is deploying... This takes 15-20 minutes."
echo "You can check status with: aws cloudfront get-distribution --id $CF_DISTRIBUTION_ID"
```

#### 8B.7 Update Frontend API URL

> **Important**: After creating the ALB in Step 9, you'll need to rebuild and redeploy the frontend with the correct API URL.

```bash
# Save this command for after ALB creation:
cat > update-frontend-api-url.sh << 'EOF'
#!/bin/bash
# Run this script after creating the ALB in Step 9

# Get ALB DNS name (set $ALB_DNS from Step 9)
cd ../../frontend

# Update API URL
cat > .env.production << ENVEOF
VITE_API_URL=http://$ALB_DNS
ENVEOF

# Rebuild
npm run build

# Re-upload to S3
aws s3 sync dist/ s3://$BUCKET_NAME/ \
  --delete \
  --cache-control "public, max-age=31536000" \
  --exclude "index.html"

aws s3 cp dist/index.html s3://$BUCKET_NAME/index.html \
  --cache-control "no-cache, no-store, must-revalidate"

# Invalidate CloudFront cache to see changes immediately
aws cloudfront create-invalidation \
  --distribution-id $CF_DISTRIBUTION_ID \
  --paths "/*"

echo "✅ Frontend updated with ALB URL!"
ENVEOF

chmod +x update-frontend-api-url.sh
echo "💾 Script saved: update-frontend-api-url.sh (run this after Step 9)"
```

**✅ If you chose Option B, continue to Step 9**

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

### 9.2 Create Backend Target Group

> **What are Target Groups?**
> Target groups define where the ALB should send traffic. The backend target group is needed for both deployment options.

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
```

### 9.3 Register Backend Instance

```bash
# Register the backend instance with its target group
aws elbv2 register-targets --target-group-arn $BACKEND_TG_ARN --targets Id=$BACKEND_INSTANCE_ID
```

### 9.4 Create Listener - Choose Based on Your Frontend Option

#### If you chose Option A (EC2 Frontend):

```bash
# First create Frontend Target Group
aws elbv2 create-target-group \
  --name aws-demo-frontend-tg \
  --protocol HTTP \
  --port 80 \
  --vpc-id $VPC_ID \
  --health-check-path // \
  --target-type instance

export FRONTEND_TG_ARN=arn:aws:elasticloadbalancing:...

# Register frontend instance
aws elbv2 register-targets --target-group-arn $FRONTEND_TG_ARN --targets Id=$FRONTEND_INSTANCE_ID

# Create listener with frontend as default action
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$FRONTEND_TG_ARN

export LISTENER_ARN=arn:aws:elasticloadbalancing:...

# Add rule to route /api/* to backend
aws elbv2 create-rule \
  --listener-arn $LISTENER_ARN \
  --priority 10 \
  --conditions Field=path-pattern,Values='/api/*' \
  --actions Type=forward,TargetGroupArn=$BACKEND_TG_ARN
```

#### If you chose Option B (S3 + CloudFront Frontend):

> **For S3 + CloudFront**: The ALB only handles API requests. Frontend is served by CloudFront.

```bash
# Create listener that ONLY routes /api/* to backend
# All other traffic will get a 404 (which is fine - users access CloudFront directly)
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=fixed-response,FixedResponseConfig="{StatusCode=404,ContentType=text/plain,MessageBody='Not Found - Use CloudFront URL for frontend'}"

export LISTENER_ARN=arn:aws:elasticloadbalancing:...

# Add rule to route /api/* to backend
aws elbv2 create-rule \
  --listener-arn $LISTENER_ARN \
  --priority 10 \
  --conditions Field=path-pattern,Values='/api/*' \
  --actions Type=forward,TargetGroupArn=$BACKEND_TG_ARN

# Get ALB DNS for updating frontend config
ALB_DNS=$(aws elbv2 describe-load-balancers --names aws-demo-alb --query 'LoadBalancers[0].DNSName' --output text)
echo "ALB DNS: $ALB_DNS"
export ALB_DNS

# NOW run the update script we created earlier:
echo "⚠️ IMPORTANT: Run the update script to rebuild frontend with correct API URL:"
echo "cd infrastructure/1-ec2"
echo "BUCKET_NAME=$BUCKET_NAME CF_DISTRIBUTION_ID=$CF_DISTRIBUTION_ID ALB_DNS=$ALB_DNS bash update-frontend-api-url.sh"
```

---

## Step 10: Test the Deployment

### For Option A (EC2 Frontend):

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

### For Option B (S3 + CloudFront Frontend):

```bash
# Your frontend URL is the CloudFront domain (from Step 8B.6)
echo "Frontend URL: https://$CLOUDFRONT_DOMAIN"
echo "Backend API URL: http://$ALB_DNS"

# Test backend API directly
curl http://$ALB_DNS/api/messages

# Test creating a message
curl -X POST http://$ALB_DNS/api/messages \
  -H "Content-Type: application/json" \
  -d '{"content": "Hello from S3 + CloudFront!"}'

# Open frontend in browser
echo "🌐 Open in browser: https://$CLOUDFRONT_DOMAIN"

# Check CloudFront distribution status
aws cloudfront get-distribution --id $CF_DISTRIBUTION_ID --query 'Distribution.Status' --output text
# Should show "Deployed" when ready (takes 15-20 minutes after creation)
```

---

## Troubleshooting

### For Option A - Check EC2 Instance Status

```bash
# View instance status
aws ec2 describe-instance-status --instance-ids $BACKEND_INSTANCE_ID $FRONTEND_INSTANCE_ID

# SSH into backend to check logs
ssh -i aws-demo-key.pem ec2-user@<BACKEND_PUBLIC_IP>
sudo docker logs backend

# SSH into frontend to check logs
ssh -i aws-demo-key.pem ec2-user@<FRONTEND_PUBLIC_IP>
sudo docker logs frontend
```

### For Option B - Check S3 and CloudFront

```bash
# List files in S3 bucket
aws s3 ls s3://$BUCKET_NAME/ --recursive

# Check CloudFront distribution status
aws cloudfront get-distribution --id $CF_DISTRIBUTION_ID

# Test CloudFront cache
curl -I https://$CLOUDFRONT_DOMAIN
# Look for "X-Cache: Hit from cloudfront" header (means cached)

# Invalidate CloudFront cache if you updated files
aws cloudfront create-invalidation \
  --distribution-id $CF_DISTRIBUTION_ID \
  --paths "/*"
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
