output "eb_environment_url" {
  description = "Elastic Beanstalk environment URL"
  value       = "http://${aws_elastic_beanstalk_environment.backend.cname}"
}

output "eb_environment_name" {
  description = "Elastic Beanstalk environment name"
  value       = aws_elastic_beanstalk_environment.backend.name
}

output "s3_bucket_name" {
  description = "S3 bucket name for frontend"
  value       = aws_s3_bucket.frontend.bucket
}

output "s3_website_url" {
  description = "S3 website URL"
  value       = aws_s3_bucket_website_configuration.frontend.website_endpoint
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "application_url" {
  description = "Application URL (via CloudFront)"
  value       = "https://${aws_cloudfront_distribution.main.domain_name}"
}
