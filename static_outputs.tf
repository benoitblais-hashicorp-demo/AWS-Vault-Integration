output "rds_endpoint_static" {
  description = "The endpoint of the Static RDS instance"
  value       = aws_db_instance.db_static.endpoint
}

output "web_static_public_ip" {
  description = "The public IP of the Static web server"
  value       = module.web_static.public_ip
}

output "website_url_static" {
  description = "The URL of the static application"
  value       = "https://web-static.${var.public_hosted_zone}"
}

output "secrets_manager_os_arn" {
  description = "The ARN of the AWS Secret containing the static OS passwords"
  value       = aws_secretsmanager_secret.os_linuxadmin.arn
}

output "secrets_manager_db_arn" {
  description = "The ARN of the AWS Secret containing the static Database passwords"
  value       = aws_secretsmanager_secret.db_password.arn
}
