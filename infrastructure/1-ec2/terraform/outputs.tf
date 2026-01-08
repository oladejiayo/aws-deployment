output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "backend_instance_id" {
  description = "Backend EC2 instance ID"
  value       = aws_instance.backend.id
}

output "frontend_instance_id" {
  description = "Frontend EC2 instance ID (only for EC2 deployment)"
  value       = var.frontend_deployment_type == "ec2" ? aws_instance.frontend[0].id : null
}

output "backend_public_ip" {
  description = "Backend EC2 public IP"
  value       = aws_instance.backend.public_ip
}

output "frontend_public_ip" {
  description = "Frontend EC2 public IP (only for EC2 deployment)"
  value       = var.frontend_deployment_type == "ec2" ? aws_instance.frontend[0].public_ip : null
}

output "s3_bucket_name" {
  description = "S3 bucket name for frontend (only for S3+CloudFront deployment)"
  value       = var.frontend_deployment_type == "s3_cloudfront" ? aws_s3_bucket.frontend[0].id : null
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain (only for S3+CloudFront deployment)"
  value       = var.frontend_deployment_type == "s3_cloudfront" ? aws_cloudfront_distribution.frontend[0].domain_name : null
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (only for S3+CloudFront deployment)"
  value       = var.frontend_deployment_type == "s3_cloudfront" ? aws_cloudfront_distribution.frontend[0].id : null
}

output "application_url" {
  description = "Application URL"
  value       = var.frontend_deployment_type == "ec2" ? "http://${aws_lb.main.dns_name}" : "https://${aws_cloudfront_distribution.frontend[0].domain_name}"
}
