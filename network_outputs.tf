output "vpc_id" {
  description = "The ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_private_subnets" {
  description = "List of private subnets in the VPC."
  value       = module.vpc.private_subnets
}

output "vpc_public_subnets" {
  description = "List of public subnets in the VPC."
  value       = module.vpc.public_subnets
}
