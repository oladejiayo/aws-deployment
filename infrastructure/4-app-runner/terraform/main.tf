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
# Data Sources
# =============================================================================
data "terraform_remote_state" "common" {
  backend = "local"
  config = {
    path = "../../common/terraform/terraform.tfstate"
  }
}

data "aws_caller_identity" "current" {}

# =============================================================================
# IAM Role for App Runner ECR Access
# =============================================================================
resource "aws_iam_role" "apprunner_ecr_access" {
  name = "${var.project_name}-apprunner-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "apprunner_ecr_access" {
  role       = aws_iam_role.apprunner_ecr_access.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

# =============================================================================
# IAM Role for App Runner Instance
# =============================================================================
resource "aws_iam_role" "apprunner_instance" {
  name = "${var.project_name}-apprunner-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "tasks.apprunner.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# =============================================================================
# VPC Connector for RDS Access
# =============================================================================
resource "aws_apprunner_vpc_connector" "main" {
  vpc_connector_name = "${var.project_name}-vpc-connector"
  subnets            = data.terraform_remote_state.common.outputs.private_subnet_ids
  security_groups    = [data.terraform_remote_state.common.outputs.app_security_group_id]

  tags = {
    Name = "${var.project_name}-vpc-connector"
  }
}

# =============================================================================
# Auto Scaling Configuration
# =============================================================================
resource "aws_apprunner_auto_scaling_configuration_version" "main" {
  auto_scaling_configuration_name = "${var.project_name}-autoscaling"

  max_concurrency = 100
  max_size        = 10
  min_size        = 1

  tags = {
    Name = "${var.project_name}-autoscaling"
  }
}

# =============================================================================
# Backend App Runner Service
# =============================================================================
resource "aws_apprunner_service" "backend" {
  service_name = "${var.project_name}-backend"

  source_configuration {
    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner_ecr_access.arn
    }

    auto_deployments_enabled = true

    image_repository {
      image_identifier      = "${data.terraform_remote_state.common.outputs.ecr_backend_url}:latest"
      image_repository_type = "ECR"

      image_configuration {
        port = "8080"

        runtime_environment_variables = {
          DATABASE_URL      = data.terraform_remote_state.common.outputs.database_url
          DATABASE_USER     = var.db_username
          DATABASE_PASSWORD = var.db_password
        }
      }
    }
  }

  instance_configuration {
    cpu               = "256"
    memory            = "512"
    instance_role_arn = aws_iam_role.apprunner_instance.arn
  }

  network_configuration {
    egress_configuration {
      egress_type       = "VPC"
      vpc_connector_arn = aws_apprunner_vpc_connector.main.arn
    }
  }

  health_check_configuration {
    protocol            = "HTTP"
    path                = "/api/messages"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 1
    unhealthy_threshold = 5
  }

  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.main.arn

  tags = {
    Name = "${var.project_name}-backend"
  }
}

# =============================================================================
# Frontend App Runner Service
# =============================================================================
resource "aws_apprunner_service" "frontend" {
  service_name = "${var.project_name}-frontend"

  source_configuration {
    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner_ecr_access.arn
    }

    auto_deployments_enabled = true

    image_repository {
      image_identifier      = "${data.terraform_remote_state.common.outputs.ecr_frontend_url}:latest"
      image_repository_type = "ECR"

      image_configuration {
        port = "80"

        runtime_environment_variables = {
          BACKEND_URL = "https://${aws_apprunner_service.backend.service_url}"
        }
      }
    }
  }

  instance_configuration {
    cpu    = "256"
    memory = "512"
  }

  health_check_configuration {
    protocol            = "HTTP"
    path                = "/"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 1
    unhealthy_threshold = 5
  }

  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.main.arn

  tags = {
    Name = "${var.project_name}-frontend"
  }

  depends_on = [aws_apprunner_service.backend]
}
