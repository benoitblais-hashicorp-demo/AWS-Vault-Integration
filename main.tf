data "aws_availability_zones" "available" {
  state = "available"
}

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

# Security Group for the Application Load Balancer
module "alb_sg" {
  source  = "app.terraform.io/benoitblais-hashicorp/security-group/aws"
  version = "0.0.2"

  name        = "alb-sg"
  description = "Security group for ALB allowing public HTTP/HTTPS"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]

  egress_rules = ["all-all"]
}

# Security Group for the Web Server (Private)
module "web_server_sg" {
  source  = "app.terraform.io/benoitblais-hashicorp/security-group/aws"
  version = "0.0.2"

  name        = "web-server-sg"
  description = "Security group for web server allowing traffic only from ALB"
  vpc_id      = module.vpc.vpc_id

  # Only allow traffic from the ALB
  ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.alb_sg.security_group_id
    },
    {
      rule                     = "https-443-tcp"
      source_security_group_id = module.alb_sg.security_group_id
    }
  ]

  egress_rules = ["all-all"]
}

# Application Load Balancer
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.0"

  name    = "web-alb"
  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  # Ensure the security group is correctly passed
  security_groups = [module.alb_sg.security_group_id]

  # For a demo, stick to HTTP to start. HTTPS can be added later when we get Vault certificates
  listeners = {
    http-80 = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "web-tg"
      }
    }
  }

  target_groups = {
    web-tg = {
      name              = "web-tg"
      protocol          = "HTTP"
      port              = 80
      target_type       = "instance"
      create_attachment = false # We attach it below
    }
  }
}

# Attach EC2 Instance to the ALB Target Group
resource "aws_lb_target_group_attachment" "web_server" {
  target_group_arn = module.alb.target_groups["web-tg"].arn
  target_id        = module.web_server.id
  port             = 80
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

  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [module.web_server_sg.security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name

  # Security best practice: IMDSv2 enabled
  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }
}
