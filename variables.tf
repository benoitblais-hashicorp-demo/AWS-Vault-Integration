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

variable "private_hosted_zone" {
  description = "(Optional) Private Route53 Hosted Zone domain name for Vault internal PKI."
  type        = string
  default     = "benoit-blais.sbx.hashidemos.local"
}

variable "public_hosted_zone" {
  description = "(Optional) Public Route53 Hosted Zone domain name for Let's Encrypt certificates and external DNS."
  type        = string
  default     = "benoit-blais.sbx.hashidemos.io"
}
