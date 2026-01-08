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

# Pull and run frontend container
docker pull ${ecr_repo}:latest
docker run -d \
  --name frontend-app \
  --restart always \
  -p 80:80 \
  ${ecr_repo}:latest
