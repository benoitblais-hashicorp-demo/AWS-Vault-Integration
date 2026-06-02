provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "Demo"
      Project     = "AWS-Vault-Integration"
      ManagedBy   = "Terraform"
    }
  }
}
