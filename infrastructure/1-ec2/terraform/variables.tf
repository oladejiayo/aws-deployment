variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "aws-demo"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
}

variable "frontend_deployment_type" {
  description = "Frontend deployment type: 'ec2' or 's3_cloudfront'"
  type        = string
  default     = "s3_cloudfront"
  validation {
    condition     = contains(["ec2", "s3_cloudfront"], var.frontend_deployment_type)
    error_message = "frontend_deployment_type must be either 'ec2' or 's3_cloudfront'."
  }
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}
