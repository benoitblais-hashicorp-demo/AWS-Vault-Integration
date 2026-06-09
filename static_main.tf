# RANDOM IDs to prevent Secrets Manager collision during destroy/reapply
resource "random_id" "static_suffix" {
  byte_length = 4
}

# ------------------------------------------------------------------------------
# SECURITY GROUPS
# ------------------------------------------------------------------------------

module "alb_static_sg" {
  source  = "app.terraform.io/benoitblais-hashicorp/security-group/aws"
  version = "0.0.2"

  name        = "alb-static-sg"
  description = "Security group for ALB allowing public HTTPS. HTTP is permitted only for 301 redirects."
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  egress_rules        = ["all-all"]
}

module "web_static_sg" {
  source  = "app.terraform.io/benoitblais-hashicorp/security-group/aws"
  version = "0.0.2"

  name        = "web-static-sg"
  description = "Security group for web server allowing traffic only from ALB"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.alb_static_sg.security_group_id
    }
  ]

  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "Access from Admin Laptop for Troubleshooting"
      cidr_blocks = var.admin_laptop_ip != "" ? var.admin_laptop_ip : "127.0.0.1/32"
    }
  ]

  egress_rules = ["all-all"]
}

module "db_static_sg" {
  source  = "app.terraform.io/benoitblais-hashicorp/security-group/aws"
  version = "0.0.2"

  name        = "db-static-sg"
  description = "Security group for database"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule                     = "postgresql-tcp"
      source_security_group_id = module.web_static_sg.security_group_id
    }
  ]

  ingress_with_cidr_blocks = [
    {
      rule        = "postgresql-tcp"
      cidr_blocks = var.admin_laptop_ip != "" ? var.admin_laptop_ip : "127.0.0.1/32"
      description = "Access from Admin Laptop for Verification"
    }
  ]
}

# ------------------------------------------------------------------------------
# AWS SECRETS MANAGER (STATIC CREDENTIALS)
# ------------------------------------------------------------------------------

# 1. OS Secrets
resource "random_password" "os_linuxadmin_password_static" {
  length           = 16
  special          = true
  override_special = "-_"
}

resource "random_password" "os_appuser_password_static" {
  length           = 16
  special          = true
  override_special = "-_"
}

resource "aws_secretsmanager_secret" "os_linuxadmin" {
  name        = "static/os/linuxadmin-${random_id.static_suffix.hex}"
  description = "Static OS password for linuxadmin"
}

resource "aws_secretsmanager_secret_version" "os_linuxadmin" {
  secret_id     = aws_secretsmanager_secret.os_linuxadmin.id
  secret_string = random_password.os_linuxadmin_password_static.result
}

# 2. Database Secrets
resource "random_password" "db_password_static" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_password" {
  name        = "static/db/dbadmin-${random_id.static_suffix.hex}"
  description = "Static DB password for dbadmin"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = "dbadmin"
    password = random_password.db_password_static.result
    engine   = "postgres"
    host     = aws_db_instance.db_static.endpoint
    port     = 5432
    dbname   = "appdb"
  })
}

# ------------------------------------------------------------------------------
# DATABASE INSTANCE
# ------------------------------------------------------------------------------

resource "aws_db_subnet_group" "static" {
  name       = "public-db-subnets-static"
  subnet_ids = module.vpc.public_subnets
}

resource "aws_db_instance" "db_static" {
  identifier        = "vault-demo-postgres-static"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  db_name           = "appdb"
  username          = "dbadmin"
  password          = random_password.db_password_static.result

  publicly_accessible    = true
  vpc_security_group_ids = [module.db_static_sg.security_group_id]
  db_subnet_group_name   = aws_db_subnet_group.static.name
  skip_final_snapshot    = true
}

# ------------------------------------------------------------------------------
# APPLICATION LOAD BALANCER & AWS ACM CERTIFICATE
# ------------------------------------------------------------------------------

# Issue Public TLS validation entirely through ACM natively
resource "aws_acm_certificate" "static_cert" {
  domain_name       = "web-static.${var.public_hosted_zone}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "acme_challenge_static" {
  for_each = {
    for dvo in aws_acm_certificate.static_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.demo.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "web_static" {
  certificate_arn         = aws_acm_certificate.static_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.acme_challenge_static : record.fqdn]
}

module "alb_static" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.0"

  name = "alb-static"

  load_balancer_type = "application"
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets
  security_groups    = [module.alb_static_sg.security_group_id]

  enable_deletion_protection = false

  listeners = {
    http-https-redirect = {
      port     = 80
      protocol = "HTTP"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    https = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = aws_acm_certificate.static_cert.arn

      forward = {
        target_group_key = "web-static-tg"
      }
    }
  }

  target_groups = {
    web-static-tg = {
      name_prefix       = "stat"
      protocol          = "HTTP"
      port              = 80
      target_type       = "instance"
      create_attachment = false
    }
  }
}

resource "aws_lb_target_group_attachment" "web_static" {
  target_group_arn = module.alb_static.target_groups["web-static-tg"].arn
  target_id        = module.web_static.id
  port             = 80
}

resource "aws_route53_record" "web_static" {
  zone_id = data.aws_route53_zone.demo.zone_id
  name    = "web-static.${var.public_hosted_zone}"
  type    = "A"

  alias {
    name                   = module.alb_static.dns_name
    zone_id                = module.alb_static.zone_id
    evaluate_target_health = true
  }
}

# ------------------------------------------------------------------------------
# IAM PROFILE FOR STATIC WEB (To demo grabbing secrets via AWS CLI on the VM)
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "static_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "static_role" {
  name               = "web-static-role-${random_id.static_suffix.hex}"
  assume_role_policy = data.aws_iam_policy_document.static_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ssm_core_static" {
  role       = aws_iam_role.static_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "secrets_manager_read" {
  role       = aws_iam_role.static_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

resource "aws_iam_instance_profile" "static_profile" {
  name = "web-static-profile-${random_id.static_suffix.hex}"
  role = aws_iam_role.static_role.name
}

# ------------------------------------------------------------------------------
# WEB INSTANCE
# ------------------------------------------------------------------------------

module "web_static" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 5.6"

  name = "web-static"

  ami           = data.aws_ami.rhel9.id
  instance_type = "t3.small"

  user_data = templatefile("${path.module}/scripts/bootstrap_web-static.sh", {
    db_host            = aws_db_instance.db_static.address
    db_port            = aws_db_instance.db_static.port
    db_name            = aws_db_instance.db_static.db_name
    db_user            = aws_db_instance.db_static.username
    db_password        = random_password.db_password_static.result
    linuxadmin_initial = random_password.os_linuxadmin_password_static.result
    appuser_initial    = random_password.os_appuser_password_static.result
  })
  user_data_replace_on_change = true

  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  vpc_security_group_ids      = [module.web_static_sg.security_group_id]
  iam_instance_profile        = aws_iam_instance_profile.static_profile.name

  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }
}