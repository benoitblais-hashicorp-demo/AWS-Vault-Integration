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
