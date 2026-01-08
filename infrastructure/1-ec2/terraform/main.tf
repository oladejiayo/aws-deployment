terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# =============================================================================
# Data Sources - Reference common infrastructure
# =============================================================================
data "terraform_remote_state" "common" {
  backend = "local"
  config = {
    path = "../../common/terraform/terraform.tfstate"
  }
}

data "aws_caller_identity" "current" {}

# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# =============================================================================
# IAM Role for EC2 to access ECR
# =============================================================================
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# =============================================================================
# EC2 Instances
# =============================================================================

# Backend EC2 Instance
resource "aws_instance" "backend" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = data.terraform_remote_state.common.outputs.public_subnet_ids[0]
  vpc_security_group_ids = [data.terraform_remote_state.common.outputs.app_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data = base64encode(templatefile("${path.module}/scripts/backend-userdata.sh", {
    aws_region     = var.aws_region
    account_id     = data.aws_caller_identity.current.account_id
    ecr_repo       = data.terraform_remote_state.common.outputs.ecr_backend_url
    database_url   = data.terraform_remote_state.common.outputs.database_url
    database_user  = var.db_username
    database_pass  = var.db_password
  }))

  tags = {
    Name = "${var.project_name}-backend"
  }
}

# Frontend EC2 Instance (only if frontend_deployment_type == "ec2")
resource "aws_instance" "frontend" {
  count                  = var.frontend_deployment_type == "ec2" ? 1 : 0
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = data.terraform_remote_state.common.outputs.public_subnet_ids[1]
  vpc_security_group_ids = [data.terraform_remote_state.common.outputs.app_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data = base64encode(templatefile("${path.module}/scripts/frontend-userdata.sh", {
    aws_region = var.aws_region
    account_id = data.aws_caller_identity.current.account_id
    ecr_repo   = data.terraform_remote_state.common.outputs.ecr_frontend_url
  }))

  tags = {
    Name = "${var.project_name}-frontend"
  }
}

# =============================================================================
# S3 + CloudFront (only if frontend_deployment_type == "s3_cloudfront")
# =============================================================================

# S3 Bucket for Static Website Hosting
resource "aws_s3_bucket" "frontend" {
  count  = var.frontend_deployment_type == "s3_cloudfront" ? 1 : 0
  bucket = "${var.project_name}-frontend-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-frontend"
  }
}

# Enable versioning
resource "aws_s3_bucket_versioning" "frontend" {
  count  = var.frontend_deployment_type == "s3_cloudfront" ? 1 : 0
  bucket = aws_s3_bucket.frontend[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Block public access (CloudFront will access via OAI)
resource "aws_s3_bucket_public_access_block" "frontend" {
  count  = var.frontend_deployment_type == "s3_cloudfront" ? 1 : 0
  bucket = aws_s3_bucket.frontend[0].id

  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

# CloudFront Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "frontend" {
  count   = var.frontend_deployment_type == "s3_cloudfront" ? 1 : 0
  comment = "OAI for ${var.project_name} frontend"
}

# S3 Bucket Policy for CloudFront
resource "aws_s3_bucket_policy" "frontend" {
  count  = var.frontend_deployment_type == "s3_cloudfront" ? 1 : 0
  bucket = aws_s3_bucket.frontend[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAI"
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.frontend[0].iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend[0].arn}/*"
      }
    ]
  })
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "frontend" {
  count   = var.frontend_deployment_type == "s3_cloudfront" ? 1 : 0
  enabled = true
  comment = "${var.project_name} frontend distribution"

  origin {
    domain_name = aws_s3_bucket.frontend[0].bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.frontend[0].id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.frontend[0].cloudfront_access_identity_path
    }
  }

  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.frontend[0].id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400   # 1 day
    max_ttl                = 31536000 # 1 year
    compress               = true
  }

  # Custom error response for SPA routing
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
    error_caching_min_ttl = 300
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  price_class = "PriceClass_100" # Use only North America and Europe edge locations

  tags = {
    Name = "${var.project_name}-frontend-cdn"
  }
}

# =============================================================================
# Application Load Balancer
# =============================================================================
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [data.terraform_remote_state.common.outputs.alb_security_group_id]
  subnets            = data.terraform_remote_state.common.outputs.public_subnet_ids

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# Backend Target Group
resource "aws_lb_target_group" "backend" {
  name     = "${var.project_name}-backend-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.terraform_remote_state.common.outputs.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/api/messages"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
}

# Frontend Target Group (only if frontend_deployment_type == "ec2")
resource "aws_lb_target_group" "frontend" {
  count    = var.frontend_deployment_type == "ec2" ? 1 : 0
  name     = "${var.project_name}-frontend-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.terraform_remote_state.common.outputs.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
}

# Register Targets
resource "aws_lb_target_group_attachment" "backend" {
  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = aws_instance.backend.id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "frontend" {
  count            = var.frontend_deployment_type == "ec2" ? 1 : 0
  target_group_arn = aws_lb_target_group.frontend[0].arn
  target_id        = aws_instance.frontend[0].id
  port             = 80
}

# ALB Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  # Default action depends on frontend deployment type
  default_action {
    type = var.frontend_deployment_type == "ec2" ? "forward" : "fixed-response"

    # For EC2: forward to frontend target group
    target_group_arn = var.frontend_deployment_type == "ec2" ? aws_lb_target_group.frontend[0].arn : null

    # For S3+CloudFront: return 404 (frontend is served by CloudFront)
    dynamic "fixed_response" {
      for_each = var.frontend_deployment_type == "s3_cloudfront" ? [1] : []
      content {
        content_type = "text/plain"
        message_body = "Not Found - Use CloudFront URL for frontend"
        status_code  = "404"
      }
    }
  }
}

# Listener Rule for API
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}
