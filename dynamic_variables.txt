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

variable "admin_laptop_ip" {
  description = "(Optional) Public IP of your local laptop allowed to connect directly to the RDS instance for demo verification. Needs /32 suffix."
  type        = string
  default     = "" # Replace with your IP e.g. "123.45.67.89/32"
}
