output "vpc_id" {
  description = "The ID of the VPC."
  value       = module.vpc.vpc_id
}

output "web_server_id" {
  description = "The instance ID of the web server."
  value       = module.web_server.id
}

output "web_server_public_ip" {
  description = "The public IP address of the web server."
  value       = module.web_server.public_ip
}
