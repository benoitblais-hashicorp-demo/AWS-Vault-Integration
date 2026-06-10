variable "force_cert_rotation" {
  description = "(Optional) A trigger to forcefully rotate the ALB Let's Encrypt certificate prematurely during demonstrations. Change this value to force rotation."
  type        = string
  default     = "1"
}

variable "vault_server_ip" {
  description = "(Required) The public IP address of the Vault server allowed to access the RDS database."
  type        = string
}

variable "acme_email" {
  description = "(Optional) Email address for Let's Encrypt ACME account registration."
  type        = string
  default     = "benoit.blais@ibm.com"
}
