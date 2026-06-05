variable "aws_region" {
  description = "The AWS region to deploy resources into."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "vault_address" {
  description = "The URL of your Vault instance"
  type        = string
}

variable "vault_token" {
  description = "Vault token with administrative privileges"
  type        = string
  sensitive   = true
}
