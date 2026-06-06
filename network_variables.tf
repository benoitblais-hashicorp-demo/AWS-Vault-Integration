variable "vpc_cidr" {
  description = "(Optional) The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_name" {
  description = "(Optional) The name of the VPC."
  type        = string
  default     = "web-infra-vpc"
}
