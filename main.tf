# Security Group for the Application Load Balancer
module "alb_dynamic_sg" {
  source  = "app.terraform.io/benoitblais-hashicorp/security-group/aws"
  version = "0.0.2"

  name        = "alb-dynamic-sg"
  description = "Security group for ALB allowing public HTTP/HTTPS"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]

  egress_rules = ["all-all"]
}

# Security Group for the Web Server (Private)
module "web_dynamic_sg" {
  source  = "app.terraform.io/benoitblais-hashicorp/security-group/aws"
  version = "0.0.2"

  name        = "web-dynamic-sg"
  description = "Security group for web server allowing traffic only from ALB"
  vpc_id      = module.vpc.vpc_id

  # Only allow traffic from the ALB
  ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.alb_dynamic_sg.security_group_id
    },
    {
      rule                     = "https-443-tcp"
      source_security_group_id = module.alb_dynamic_sg.security_group_id
    }
  ]

  # Allow SSH from Vault Server (Temporary 0.0.0.0/0 to ensure avoiding dynamic IP drops)
  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "SSH from Vault"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  egress_rules = ["all-all"]
}

# Application Load Balancer
module "alb_dynamic" {
  source  = "app.terraform.io/benoitblais-hashicorp/alb/aws"
  version = "0.0.1"

  name    = "alb-dynamic"
  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets
  
  # Allow Terraform to delete this ALB if we destroy the environment
  enable_deletion_protection = false

  # Ensure the security group is correctly passed
  security_groups = [module.alb_dynamic_sg.security_group_id]

  # For a demo, stick to HTTP to start. HTTPS can be added later when we get Vault certificates
  listeners = {
    http-80 = {
      port     = 80
      protocol = "HTTP"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
    https-443 = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = aws_acm_certificate.web.arn
      forward = {
        target_group_key = "web-dynamic-tg"
      }
    }
  }

  target_groups = {
    web-dynamic-tg = {
      name              = "web-dynamic-tg"
      protocol          = "HTTP"
      port              = 80
      target_type       = "instance"
      create_attachment = false # We attach it below
    }
  }
}

# Attach EC2 Instance to the ALB Target Group
resource "aws_lb_target_group_attachment" "web_dynamic" {
  target_group_arn = module.alb_dynamic.target_groups["web-dynamic-tg"].arn
  target_id        = module.web_dynamic.id
  port             = 80
}

# IAM Role for SSM Session Manager (Security Best Practice: No inbound SSH)
resource "aws_iam_role" "ssm_role" {
  name = "web_dynamic_ssm_role"

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
  name = "web_dynamic_ssm_profile"
  role = aws_iam_role.ssm_role.name
}

# EC2 Instance
module "web_dynamic" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 5.6"

  name = "web-dynamic"

  ami           = data.aws_ami.rhel9.id
  instance_type = "t3.small"

  # Inject startup script to seed the DB and install the web app
  user_data = templatefile("${path.module}/scripts/bootstrap_web-dynamic.sh", {
    db_host            = aws_db_instance.db_dynamic.address
    db_port            = aws_db_instance.db_dynamic.port
    db_name            = aws_db_instance.db_dynamic.db_name
    db_user            = aws_db_instance.db_dynamic.username
    db_password        = aws_db_instance.db_dynamic.password
    linuxadmin_initial = random_password.os_linuxadmin_password.result
    appuser_initial    = random_password.os_appuser_password.result
  })
  user_data_replace_on_change = true

  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  vpc_security_group_ids      = [module.web_dynamic_sg.security_group_id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name

  # Security best practice: IMDSv2 enabled
  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }
}

# RDS Security Group
module "db_dynamic_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "db-dynamic-sg"
  description = "Security group for RDS allowing Vault and Web Server"
  vpc_id      = module.vpc.vpc_id

  # Allow access from the Vault Server IP only
  ingress_with_cidr_blocks = [
    {
      rule        = "postgresql-tcp"
      cidr_blocks = "${var.vault_server_ip}/32"
      description = "Access from external Vault server"
    }
  ]

  # Allow access from the Web Server
  ingress_with_source_security_group_id = [
    {
      rule                     = "postgresql-tcp"
      source_security_group_id = module.web_dynamic_sg.security_group_id
      description              = "Access from internal Web Server"
    }
  ]

  egress_rules = ["all-all"]
}

resource "aws_db_subnet_group" "public" {
  name = "public-db-subnets"
  # Placed in the public subnets so external Vault can reach it for JIT secret generation
  subnet_ids = module.vpc.public_subnets
}

# AWS RDS PostgreSQL Instance
resource "aws_db_instance" "db_dynamic" {
  identifier        = "vault-demo-postgres"
  engine            = "postgres"
  engine_version    = "15" # AWS will use the most robust available 15.x patch
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  db_name           = "appdb"
  username          = "dbadmin"
  password          = random_password.db_password.result

  # Required to be Public so external Vault can connect and manage roles
  publicly_accessible    = true
  vpc_security_group_ids = [module.db_dynamic_sg.security_group_id]
  db_subnet_group_name   = aws_db_subnet_group.public.name
  skip_final_snapshot    = true
}

# Generate a high-entropy password for the RDS instance natively in Terraform
resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Generate passwords for OS users natively in Terraform
resource "random_password" "os_linuxadmin_password" {
  length           = 32
  special          = true
  override_special = "!@#$%^&*"
}

resource "random_password" "os_appuser_password" {
  length           = 32
  special          = true
  override_special = "!@#$%^&*"
}
