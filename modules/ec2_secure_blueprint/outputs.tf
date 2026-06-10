output "instance_id" {
  description = "The EC2 instance ID"
  value       = module.ec2.id
}

output "public_ip" {
  description = "The public IP of the EC2 instance"
  value       = module.ec2.public_ip
}

output "private_ip" {
  description = "The private IP of the EC2 instance"
  value       = module.ec2.private_ip
}

output "security_group_id" {
  description = "The associated local security group ID"
  value       = module.sg.security_group_id
}

output "vault_host_path" {
  description = "The path in Vault to read credentials for this host"
  value       = "${var.vault_os_mount_path}/hosts/${vault_os_secret_backend_host.this.name}"
}
