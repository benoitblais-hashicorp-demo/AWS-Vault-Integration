data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Configuration
module "vpc" {
  source  = "app.terraform.io/benoitblais-hashicorp/vpc/aws"
  version = "0.0.1"

  name = "web-infra-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets  = [for k, v in slice(data.aws_availability_zones.available.names, 0, 2) : cidrsubnet(var.vpc_cidr, 8, k + 1)]
  private_subnets = [for k, v in slice(data.aws_availability_zones.available.names, 0, 2) : cidrsubnet(var.vpc_cidr, 8, k + 10)]

  # Public subnets need to auto-assign public IPs for ALB and NAT GW
  map_public_ip_on_launch = true

  # Enable NAT Gateway for the private subnets to reach out (patching, Vault, etc.)
  enable_nat_gateway     = true
  single_nat_gateway     = true # Cost savings: 1 NAT GW for the demo instead of 1 per AZ
  one_nat_gateway_per_az = false

  enable_vpn_gateway = false
}
