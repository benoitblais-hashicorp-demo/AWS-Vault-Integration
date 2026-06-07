# Fetch the most recent private RHEL 9 AMI
data "aws_ami" "rhel9" {
  most_recent = true
  owners      = ["888995627335"] # ami-prod account

  filter {
    name   = "name"
    values = ["hc-base-rhel-9-x86_64-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Fetch the existing Route 53 zone for public DNS records
data "aws_route53_zone" "demo" {
  name = var.public_hosted_zone
}

# Fetch the existing Route 53 zone for internal DNS records
data "aws_route53_zone" "internal" {
  name         = var.private_hosted_zone
  private_zone = true
}
