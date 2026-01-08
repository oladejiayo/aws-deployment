#!/bin/bash
set -e

# Update system
yum update -y
yum install -y docker

# Start Docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Login to ECR
aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${account_id}.dkr.ecr.${aws_region}.amazonaws.com

# Pull and run backend container
docker pull ${ecr_repo}:latest
docker run -d \
  --name backend \
  --restart always \
  -p 8080:8080 \
  -e DATABASE_URL=${database_url} \
  -e DATABASE_USER=${database_user} \
  -e DATABASE_PASSWORD=${database_pass} \
  ${ecr_repo}:latest
