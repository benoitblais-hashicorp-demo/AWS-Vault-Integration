variable "name" {
  description = "The absolute name of the EC2 instance and Vault host registration"
  type        = string
}

variable "ami" {
  description = "The AMI ID to launch, should be RHEL or compatible"
  type        = string
}

variable "instance_type" {
  description = "The type of EC2 instance to launch"
  type        = string
  default     = "t3.small"
}

variable "vpc_id" {
  description = "The VPC ID where the security group will be created"
  type        = string
}

variable "subnet_id" {
  description = "The VPC Subnet ID to launch the instance in"
  type        = string
}

variable "associate_public_ip_address" {
  description = "Whether to associate a public IP address with the EC2 instance"
  type        = bool
  default     = false
}

variable "custom_user_data" {
  description = "A custom bash script (user data) to append AFTER the Vault OS credential bootstrapping phase"
  type        = string
  default     = ""
}

# --- SG Rules ---

variable "ingress_with_cidr_blocks" {
  description = "List of ingress rules with CIDR blocks for the instance security group"
  type        = list(map(string))
  default     = []
}

variable "ingress_with_source_security_group_id" {
  description = "List of ingress rules with source security group IDs"
  type        = list(map(string))
  default     = []
}

variable "egress_rules" {
  description = "List of egress rules to create by default"
  type        = list(string)
  default     = ["all-all"]
}

variable "additional_security_group_ids" {
  description = "A list of any extra custom security group IDs to associate with the instance"
  type        = list(string)
  default     = []
}

# --- Vault Integration ---

variable "vault_namespace" {
  description = "The full path to the Vault namespace (e.g. 'admin/my-namespace')"
  type        = string
}

variable "vault_os_mount_path" {
  description = "The mount path of the OS secret backend in Vault (must already exist)"
  type        = string
  default     = "os"
}

variable "password_policy_name" {
  description = "The name of the strict password policy to assign to the Vault host"
  type        = string
}

variable "vault_rotation_period" {
  description = "The rotation period in seconds for the Vault-managed passwords"
  type        = number
  default     = 86400
}
