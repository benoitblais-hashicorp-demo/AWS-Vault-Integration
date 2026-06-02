data "aws_availability_zones" "available" {
  state = "available"
}

# Fetch the most recent private RHEL 9 AMI
data "aws_ami" "rhel9" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["hc-base-rhel-9-x86_64-*"]
  }
}

# VPC Configuration
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "web-infra-vpc"
  cidr = var.vpc_cidr

  azs            = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets = [for k, v in slice(data.aws_availability_zones.available.names, 0, 2) : cidrsubnet(var.vpc_cidr, 8, k + 1)]

  # Public subnets need to auto-assign public IPs for the instance to be reachable
  map_public_ip_on_launch = true

  enable_nat_gateway = false
  enable_vpn_gateway = false
}

# Security Group for the Web Server
module "web_server_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "web-server-sg"
  description = "Security group for web server allowing HTTP/HTTPS"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]

  egress_rules = ["all-all"]
}

# IAM Role for SSM Session Manager (Security Best Practice: No inbound SSH)
resource "aws_iam_role" "ssm_role" {
  name = "web_server_ssm_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "web_server_ssm_profile"
  role = aws_iam_role.ssm_role.name
}

# EC2 Instance
module "web_server" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 5.6"

  name = "web-server"

  ami           = data.aws_ami.rhel9.id
  instance_type = "t3.micro"
  
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [module.web_server_sg.security_group_id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name

  # Security best practice: IMDSv2 enabled
  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }
}
