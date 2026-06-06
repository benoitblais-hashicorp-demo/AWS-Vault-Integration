output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer."
  value       = module.alb_dynamic.dns_name
}

output "linuxadmin_password" {
  description = "The auto-generated initial password for the linuxadmin OS user"
  value       = random_password.os_linuxadmin_password.result
  sensitive   = true
}

output "rds_endpoint" {
  description = "The endpoint of the RDS instance"
  value       = aws_db_instance.db_dynamic.endpoint
}

output "web_dynamic_id" {
  description = "The instance ID of the web server."
  value       = module.web_dynamic.id
}

output "web_dynamic_public_ip" {
  description = "The public IP of the web server"
  value       = module.web_dynamic.public_ip
}

output "website_url" {
  description = "The final secured URL of your application"
  value       = "https://web.benoit-blais.sbx.hashidemos.io"
}
