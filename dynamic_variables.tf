variable "vault_server_ip" {
  description = "(Optional) The public IP address of the Vault server allowed to access the RDS database."
  type        = string
  default     = "3.86.9.84"
}

variable "admin_laptop_ip" {
  description = "(Optional) Public IP of your local laptop allowed to connect directly to the RDS instance for demo verification. Needs /32 suffix."
  type        = string
  default     = "" # Replace with your IP e.g. "123.45.67.89/32"
}
