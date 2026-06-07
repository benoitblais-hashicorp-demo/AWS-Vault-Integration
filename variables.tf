variable "vault_address" {
  description = "(Required) The URL of your Vault instance."
  type        = string
}

variable "vault_token" {
  description = "(Required) Vault token with administrative privileges."
  type        = string
  sensitive   = true
}

variable "aws_region" {
  description = "(Optional) The AWS region to deploy resources into."
  type        = string
  default     = "ca-central-1"
}

