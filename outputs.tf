output "vpc_id" {
  description = "The ID of the VPC."
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer."
  value       = module.alb.dns_name
}

output "web_server_id" {
  description = "The instance ID of the web server."
  value       = module.web_server.id
}

output "rds_endpoint" {
  description = "The endpoint of the RDS instance"
  value       = aws_db_instance.postgres.endpoint
}

output "linuxadmin_password" {
  description = "The auto-generated initial password for the linuxadmin OS user"
  value       = random_password.os_linuxadmin_password.result
  sensitive   = true
}

output "web_server_public_ip" {
  description = "The public IP of the web server"
  value       = module.web_server.public_ip
}
