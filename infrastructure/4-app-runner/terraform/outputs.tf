output "backend_service_url" {
  description = "Backend App Runner service URL"
  value       = "https://${aws_apprunner_service.backend.service_url}"
}

output "frontend_service_url" {
  description = "Frontend App Runner service URL"
  value       = "https://${aws_apprunner_service.frontend.service_url}"
}

output "backend_service_arn" {
  description = "Backend App Runner service ARN"
  value       = aws_apprunner_service.backend.arn
}

output "frontend_service_arn" {
  description = "Frontend App Runner service ARN"
  value       = aws_apprunner_service.frontend.arn
}

output "vpc_connector_arn" {
  description = "VPC Connector ARN"
  value       = aws_apprunner_vpc_connector.main.arn
}

output "application_url" {
  description = "Application URL (Frontend)"
  value       = "https://${aws_apprunner_service.frontend.service_url}"
}
