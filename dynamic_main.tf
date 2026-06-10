# ==============================================================================
# WEB SERVER ARCHITECTURE
# ==============================================================================

# SECURITY GROUPS
# ------------------------------------------------------------------------------

# Security Group for the Application Load Balancer
# Allows public access to the web app over standard HTTP/HTTPS ports.
module "alb_dynamic_sg" {
  source  = "app.terraform.io/benoitblais-hashicorp/security-group/aws"
  version = "0.0.2"

  name        = "alb-dynamic-sg"
  description = "Security group for ALB allowing public HTTPS. HTTP is permitted only for 301 redirects."
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  # Maintain HTTP ingress purely to catch users typing 'benoit-blais.sbx...' and 301 redirect them to HTTPS.
  ingress_rules = ["http-80-tcp", "https-443-tcp"]

  egress_rules = ["all-all"]
}

# Security Group for the Web Server (Private)
# Prevents direct internet access to the EC2 instance, restricting traffic to the ALB.
# Temporarily allows Vault SSH for OS dynamic secret configuration.
module "web_dynamic_sg" {
  source  = "app.terraform.io/benoitblais-hashicorp/security-group/aws"
  version = "0.0.2"

  name        = "web-dynamic-sg"
  description = "Security group for web server allowing traffic only from ALB"
  vpc_id      = module.vpc.vpc_id

  # Only allow traffic from the ALB
  ingress_with_source_security_group_id = [
    {
      # The ALB terminates public HTTPS and forwards to the target group over internal HTTPS port 443
      rule                     = "https-443-tcp"
      source_security_group_id = module.alb_dynamic_sg.security_group_id
    }
  ]

  # Allow SSH from Vault Server to configure OS Dynamic Secrets + Admin Laptop for verification
  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "Access from external Vault server"
      cidr_blocks = "${var.vault_server_ip}/32"
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "Access from Admin Laptop for Demo Verification"
      cidr_blocks = var.admin_laptop_ip != "" ? var.admin_laptop_ip : "127.0.0.1/32"
    }
  ]

  egress_rules = ["all-all"]
}

# APPLICATION LOAD BALANCER
# ------------------------------------------------------------------------------

# Application Load Balancer
# Balances traffic to the private EC2 instances. Deletion protection disabled for easy demo teardown.
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
      certificate_arn = aws_acm_certificate.production_cert.arn
      forward = {
        target_group_key = "web-dynamic-tg"
      }
    }
  }

  target_groups = {
    web-dynamic-tg = {
      name_prefix       = "webdyn"
      protocol          = "HTTPS"
      port              = 443
      target_type       = "instance"
      create_attachment = false # We attach it below
    }
  }
}

# Attach EC2 Instance to the ALB Target Group
resource "aws_lb_target_group_attachment" "web_dynamic" {
  target_group_arn = module.alb_dynamic.target_groups["web-dynamic-tg"].arn
  target_id        = module.web_dynamic.id
  port             = 443
}

# PUBLIC CERTIFICATE ORCHESTRATION (VAULT + ACME + AWS)
# ------------------------------------------------------------------------------

# Vault Dedicated Namespace for PKI (Public and Private)
resource "vault_namespace" "demo_pki" {
  path = "demo_pki"
}

# 1. Mount the External CA Secrets Engine
resource "vault_mount" "pki_ext_ca" {
  namespace   = vault_namespace.demo_pki.path_fq
  path        = "pki-external-ca"
  type        = "pki-external-ca"
  description = "External CA Orchestration Engine for Let's Encrypt Integration"
}

# 2. Register an ACME Account with Let's Encrypt
resource "vault_pki_external_ca_secret_backend_acme_account" "lets_encrypt" {
  namespace = vault_namespace.demo_pki.path_fq
  mount     = vault_mount.pki_ext_ca.path

  name = "lets-encrypt-prod"
  # Let's Encrypt Production Directory
  directory_url  = "https://acme-v02.api.letsencrypt.org/directory"
  email_contacts = [var.acme_email]
  key_type       = "rsa-2048"

  lifecycle {
    create_before_destroy = true
  }
}

# 3. Create the Role mapped to the allowed domain
resource "vault_pki_external_ca_secret_backend_role" "web_cert_role" {
  namespace = vault_namespace.demo_pki.path_fq
  mount     = vault_mount.pki_ext_ca.path

  # Change the role name so Terraform is forced to create a fresh one mapping to the new ACME account
  name              = "web-domain-role-prod"
  acme_account_name = vault_pki_external_ca_secret_backend_acme_account.lets_encrypt.name

  # List the exact domain you wish to validate 
  allowed_domains = [
    "web-dynamic.${var.public_hosted_zone}"
  ]

  allowed_domain_options = [
    "bare_domains",
    "subdomains"
  ]

  # We are relying on the DNS challenge as requested
  allowed_challenge_types = ["dns-01"]

  csr_generate_key_type     = "rsa-2048"
  csr_identifier_population = "cn_first"

  lifecycle {
    create_before_destroy = true
  }
}

# Fetch the existing Route 53 zone for DNS records

# Initiate the ACME Certificate Order with Let's Encrypt via Vault
resource "time_rotating" "acme_cert" {
  rotation_days = 30

  triggers = {
    force_rotation = var.force_cert_rotation
  }
}

resource "vault_pki_external_ca_secret_backend_order" "prod" {
  namespace   = vault_namespace.demo_pki.path_fq
  mount       = vault_mount.pki_ext_ca.path
  role_name   = vault_pki_external_ca_secret_backend_role.web_cert_role.name
  identifiers = ["web-dynamic.${var.public_hosted_zone}"]

  lifecycle {
    replace_triggered_by  = [time_rotating.acme_cert]
    create_before_destroy = true
  }
}

# Retrieve the DNS-01 challenge instructions from Vault
data "vault_pki_external_ca_secret_backend_order_challenge" "dns" {
  namespace      = vault_namespace.demo_pki.path_fq
  mount          = vault_pki_external_ca_secret_backend_order.prod.mount
  role_name      = vault_pki_external_ca_secret_backend_order.prod.role_name
  order_id       = vault_pki_external_ca_secret_backend_order.prod.order_id
  challenge_type = "dns-01"
  identifier     = "web-dynamic.${var.public_hosted_zone}"
}

# Create the TXT Record in AWS Route53 automatically via Terraform for domain validation
resource "aws_route53_record" "acme_challenge_dynamic" {
  zone_id = data.aws_route53_zone.demo.zone_id
  name    = "_acme-challenge.web-dynamic.${var.public_hosted_zone}"
  type    = "TXT"
  ttl     = 60
  records = [data.vault_pki_external_ca_secret_backend_order_challenge.dns.key_authorization]

  lifecycle {
    create_before_destroy = true
  }
}

# Notify Let's Encrypt (Via Vault) that the record is published
resource "vault_pki_external_ca_secret_backend_order_challenge_fulfilled" "dns" {
  depends_on = [aws_route53_record.acme_challenge_dynamic]

  namespace      = vault_namespace.demo_pki.path_fq
  mount          = vault_pki_external_ca_secret_backend_order.prod.mount
  role_name      = vault_pki_external_ca_secret_backend_order.prod.role_name
  order_id       = vault_pki_external_ca_secret_backend_order.prod.order_id
  challenge_type = "dns-01"
  identifier     = "web-dynamic.${var.public_hosted_zone}"

  lifecycle {
    create_before_destroy = true
  }
}

# Fetch the Final Signed Certificate securely from Vault out of the successful order
resource "vault_pki_external_ca_secret_backend_order_certificate" "web" {
  depends_on = [vault_pki_external_ca_secret_backend_order_challenge_fulfilled.dns]

  namespace = vault_namespace.demo_pki.path_fq
  mount     = vault_pki_external_ca_secret_backend_order.prod.mount
  role_name = vault_pki_external_ca_secret_backend_order.prod.role_name
  order_id  = vault_pki_external_ca_secret_backend_order.prod.order_id

  lifecycle {
    create_before_destroy = true
  }
}

# Upload the Let's Encrypt Certificate directly into AWS Certificate Manager for the ALB
resource "aws_acm_certificate" "production_cert" {
  private_key       = vault_pki_external_ca_secret_backend_order_certificate.web.private_key
  certificate_body  = vault_pki_external_ca_secret_backend_order_certificate.web.certificate
  certificate_chain = join("\n", vault_pki_external_ca_secret_backend_order_certificate.web.ca_chain)

  tags = {
    Name = "vault-acme-cert"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Map the public website DNS fully to the AWS Load Balancer
resource "aws_route53_record" "web_dynamic" {
  zone_id = data.aws_route53_zone.demo.zone_id
  name    = "web-dynamic.${var.public_hosted_zone}"
  type    = "A"

  alias {
    name                   = module.alb_dynamic.dns_name
    zone_id                = module.alb_dynamic.zone_id
    evaluate_target_health = true
  }
}

# PRIVATE INTERNAL CERTIFICATE ORCHESTRATION (VAULT ROOT CA)
# ------------------------------------------------------------------------------

# 1. Mount the Internal PKI Secrets Engine
resource "vault_mount" "pki_internal" {
  namespace                 = vault_namespace.demo_pki.path_fq
  path                      = "pki-internal"
  type                      = "pki"
  description               = "Internal Root CA for ${var.private_hosted_zone}"
  default_lease_ttl_seconds = 86400    # 1 day
  max_lease_ttl_seconds     = 31536000 # 1 year
}

# 2. Generate the Root Certificate for the Private CA
resource "vault_pki_secret_backend_root_cert" "internal_root" {
  depends_on = [vault_mount.pki_internal]
  namespace  = vault_namespace.demo_pki.path_fq
  backend    = vault_mount.pki_internal.path

  type                 = "internal"
  common_name          = "${var.private_hosted_zone} Root CA"
  ttl                  = "315360000" # 10 years
  format               = "pem"
  private_key_format   = "der"
  key_type             = "rsa"
  key_bits             = 2048
  exclude_cn_from_sans = true
}

# 3. Create a Role for Issuing Internal Certificates
resource "vault_pki_secret_backend_role" "internal_web" {
  namespace = vault_namespace.demo_pki.path_fq
  backend   = vault_mount.pki_internal.path

  name          = "internal-web-role"
  ttl           = 86400 # Certificates valid for 24h
  allow_ip_sans = true
  key_type      = "rsa"
  key_bits      = 2048

  # Limit this role to only issue certificates for the local zone
  allowed_domains    = [var.private_hosted_zone]
  allow_subdomains   = true
  allow_glob_domains = false
  allow_any_name     = false
  enforce_hostnames  = true
  generate_lease     = true
}

# 4. AWS Authentication for Vault Agent
# ------------------------------------------------------------------------------
resource "vault_policy" "agent_pki" {
  namespace = vault_namespace.demo_pki.path_fq
  name      = "agent-pki-policy"
  policy    = <<POLICY
path "pki-internal/issue/internal-web-role" {
  capabilities = ["update"]
}
POLICY
}

resource "vault_auth_backend" "aws" {
  namespace = vault_namespace.demo_pki.path_fq
  type      = "aws"
}

resource "vault_aws_auth_backend_client" "aws" {
  namespace = vault_namespace.demo_pki.path_fq
  backend   = vault_auth_backend.aws.path
}

resource "vault_aws_auth_backend_role" "web_agent" {
  namespace                = vault_namespace.demo_pki.path_fq
  backend                  = vault_auth_backend.aws.path
  role                     = "web-agent-role"
  auth_type                = "iam"
  bound_iam_principal_arns = [aws_iam_role.ssm_role_dynamic.arn]
  resolve_aws_unique_ids   = false
  token_policies           = ["default", vault_policy.agent_pki.name]
}

# Map this directly to the Private IP of our Web Server EC2 instance
resource "aws_route53_record" "web_internal_dynamic" {
  zone_id = data.aws_route53_zone.internal.zone_id
  name    = "web-dynamic.${var.private_hosted_zone}"
  type    = "A"
  ttl     = 300
  records = [module.web_dynamic.private_ip]
}

# EC2 INSTANCE (WEB SERVER)
# ------------------------------------------------------------------------------

# IAM Role for SSM Session Manager
# Security Best Practice: No inbound SSH directly over Internet, access securely via Systems Manager
resource "aws_iam_role" "ssm_role_dynamic" {
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

resource "aws_iam_role_policy_attachment" "ssm_core_dynamic" {
  role       = aws_iam_role.ssm_role_dynamic.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile_dynamic" {
  name = "web_dynamic_ssm_profile"
  role = aws_iam_role.ssm_role_dynamic.name
}

# Generate passwords for EC2 OS users natively in Terraform to bootstrap the Vault OS Secret Engine
resource "random_password" "os_linuxadmin_password_dynamic" {
  length           = 32
  special          = true
  override_special = "-_"
}

resource "random_password" "os_appuser_password_dynamic" {
  length           = 32
  special          = true
  override_special = "-_"
}

# EC2 Instance utilizing official AWS module
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
    linuxadmin_initial = random_password.os_linuxadmin_password_dynamic.result
    appuser_initial    = random_password.os_appuser_password_dynamic.result
    # Passing Vault config to the EC2 so Vault Agent can authenticate via AWS IAM and auto-rotate internal certs
    vault_address = var.vault_address
    pki_namespace = vault_namespace.demo_pki.path_fq
    aws_auth_path = vault_auth_backend.aws.path
    private_zone  = var.private_hosted_zone
  })
  user_data_replace_on_change = true

  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  vpc_security_group_ids      = [module.web_dynamic_sg.security_group_id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile_dynamic.name

  # Security best practice: IMDSv2 enabled
  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }
}

# VAULT OS DYNAMIC SECRETS
# ------------------------------------------------------------------------------

# Vault Dedicated Namespace for OS Secrets
resource "vault_namespace" "demo" {
  path = "demo_os_secret"
}

# Strict password policy enforced by Vault for dynamic OS users
resource "vault_password_policy" "strict" {
  namespace = vault_namespace.demo.path_fq
  name      = "rhel-strict-policy"
  policy    = <<POLICY
    length = 32
    rule "charset" {
      charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
      min-chars = 4
    }
POLICY
}

# OS Secrets Engine Mount
resource "vault_mount" "os_mount" {
  namespace   = vault_namespace.demo.path_fq
  path        = "os"
  type        = "vault-plugin-secrets-os"
  description = "OS secret backend"
}

# Configure the OS Backend Engine behavior
resource "vault_os_secret_backend" "os_backend" {
  namespace                       = vault_namespace.demo.path_fq
  mount                           = vault_mount.os_mount.path
  ssh_host_key_trust_on_first_use = true
}

# Ensure the EC2 Instance has booted completely before Vault attempts to connect via SSH
resource "time_sleep" "wait_for_web_dynamic" {
  depends_on = [module.web_dynamic]

  # Using triggers ensures that the sleep timer physically restarts
  # anytime the EC2 instance ID changes due to recreation.
  triggers = {
    web_dynamic_id = module.web_dynamic.id
  }

  create_duration = "300s"
}

# Register the Dynamic EC2 Host to Vault
resource "vault_os_secret_backend_host" "web_dynamic" {
  depends_on = [time_sleep.wait_for_web_dynamic]
  namespace  = vault_namespace.demo.path_fq
  mount      = vault_os_secret_backend.os_backend.mount
  name       = "web-dynamic"

  # Using the public IP of the created web server so external Vault can reach it
  address         = module.web_dynamic.public_ip
  port            = 22
  password_policy = vault_password_policy.strict.name

  lifecycle {
    replace_triggered_by = [time_sleep.wait_for_web_dynamic]
  }
}

# Register Admin user to Vault so it manages the password lifecycle
resource "vault_os_secret_backend_account" "direct" {
  depends_on      = [vault_os_secret_backend_host.web_dynamic]
  namespace       = vault_namespace.demo.path_fq
  mount           = vault_os_secret_backend.os_backend.mount
  host            = vault_os_secret_backend_host.web_dynamic.name
  name            = "linuxadmin"
  username        = "linuxadmin"
  password_wo     = random_password.os_linuxadmin_password_dynamic.result
  rotation_period = 300 # Aggressive 5-minute rotation for demo visibility

  lifecycle {
    replace_triggered_by = [time_sleep.wait_for_web_dynamic]
  }
}

# Register Application child user under the admin account lifecycle
resource "vault_os_secret_backend_account" "child" {
  namespace          = vault_namespace.demo.path_fq
  mount              = vault_os_secret_backend.os_backend.mount
  host               = vault_os_secret_backend_host.web_dynamic.name
  name               = "appuser"
  username           = "appuser"
  password_wo        = random_password.os_appuser_password_dynamic.result
  rotation_period    = 300 # Aggressive 5-minute rotation for demo visibility
  verify_connection  = false
  parent_account_ref = vault_os_secret_backend_account.direct.name
  depends_on         = [vault_os_secret_backend_account.direct]

  lifecycle {
    replace_triggered_by = [time_sleep.wait_for_web_dynamic]
  }
}

# Vault ACL Policy allowing read operations on OS secrets
resource "vault_policy" "host_readers" {
  namespace = vault_namespace.demo.path_fq
  name      = "policy-os-web-dynamic-reader"
  policy    = <<POLICY
path "os/hosts/web-dynamic/accounts/*/creds" {
  capabilities = ["read"]
}
POLICY
}

# ==============================================================================
# DATABASE ARCHITECTURE
# ==============================================================================

# DATABASE SECURITY GROUP
# ------------------------------------------------------------------------------

# Database Security Group
# Required to accept connections from Vault to rotate dynamic secrets,
# as well as the Web Server hosting the frontend application.
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
    },
    {
      rule        = "postgresql-tcp"
      cidr_blocks = var.admin_laptop_ip != "" ? var.admin_laptop_ip : "127.0.0.1/32"
      description = "Access from Admin Laptop for Demo Verification"
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

# DATABASE INSTANCE
# ------------------------------------------------------------------------------

# DB Subnet Group mapped to Public Subnets for Vault accessibility
resource "aws_db_subnet_group" "dynamic" {
  name = "public-db-subnets"
  # Placed in the public subnets so external Vault can reach it for JIT secret generation
  subnet_ids = module.vpc.public_subnets
}

# Database credentials injected temporarily to application script during startup
# In a full Vault adoption, Vault agent would fetch this directly without being rendered here.
resource "random_password" "db_password_dynamic" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# AWS RDS PostgreSQL Instance
# Configured as publicly accessible purely for the demo so external Vault can 
# route internal dynamic DB secrets without a VPN/VPC connection.
# Deletion protection is skipped so tear-downs are seamless.
resource "aws_db_instance" "db_dynamic" {
  identifier        = "vault-demo-postgres"
  engine            = "postgres"
  engine_version    = "15" # AWS will use the most robust available 15.x patch
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  db_name           = "appdb"
  username          = "dbadmin"
  password          = random_password.db_password_dynamic.result

  # Required to be Public so external Vault can connect and manage roles
  publicly_accessible    = true
  vpc_security_group_ids = [module.db_dynamic_sg.security_group_id]
  db_subnet_group_name   = aws_db_subnet_group.dynamic.name
  skip_final_snapshot    = true
}

# VAULT DATABASE DYNAMIC SECRETS
# ------------------------------------------------------------------------------

# Vault Dedicated Namespace for DB Secrets
resource "vault_namespace" "db" {
  path = "demo_database"
}

# Mount the Database Secrets Engine
resource "vault_mount" "db" {
  namespace   = vault_namespace.db.path_fq
  path        = "database"
  type        = "database"
  description = "Dynamic credentials for AWS RDS PostgreSQL"
}

# Configure the PostgreSQL Database Connection inside Vault
resource "vault_database_secret_backend_connection" "postgres" {
  namespace     = vault_namespace.db.path_fq
  backend       = vault_mount.db.path
  name          = "aws-rds-db-dynamic"
  allowed_roles = ["readonly", "webapp"]

  postgresql {
    connection_url = "postgresql://{{username}}:{{password}}@${aws_db_instance.db_dynamic.endpoint}/${aws_db_instance.db_dynamic.db_name}"
    username       = aws_db_instance.db_dynamic.username
    password       = aws_db_instance.db_dynamic.password
  }
}

# Create a Database Role mapped to dynamically generated credentials
# Limits lateral movement by generating one-off temporary passwords 
resource "vault_database_secret_backend_role" "webapp" {
  namespace = vault_namespace.db.path_fq
  backend   = vault_mount.db.path
  name      = "webapp"
  db_name   = vault_database_secret_backend_connection.postgres.name
  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT SELECT, UPDATE, INSERT, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";"
  ]
  default_ttl = 300  # 5 minutes for rapid demo expiration
  max_ttl     = 3600 # 1 hour max
}

# Generate an ACL Policy mapped for consuming the dynamic DB role
resource "vault_policy" "webapp_db_policy" {
  namespace = vault_namespace.db.path_fq
  name      = "webapp-database-policy"
  policy    = <<POLICY
# Allow generating dynamic database credentials
path "database/creds/webapp" {
  capabilities = ["read"]
}
POLICY
}
