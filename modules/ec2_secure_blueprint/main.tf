# ------------------------------------------------------------------------------
# IAM ROLE & INSTANCE PROFILE (SSM)
# ------------------------------------------------------------------------------

resource "aws_iam_role" "this" {
  name = "$${var.name}_ssm_role"

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
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name = "$${var.name}_ssm_profile"
  role = aws_iam_role.this.name
}

# ------------------------------------------------------------------------------
# SECURITY GROUP
# ------------------------------------------------------------------------------

module "sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "$${var.name}-sg"
  description = "Security group for Blueprint EC2 instance $${var.name}"
  vpc_id      = var.vpc_id

  ingress_with_cidr_blocks              = var.ingress_with_cidr_blocks
  ingress_with_source_security_group_id = var.ingress_with_source_security_group_id
  egress_rules                          = var.egress_rules
}

# ------------------------------------------------------------------------------
# EC2 PASSWORDS & INSTANCE
# ------------------------------------------------------------------------------

resource "random_password" "os_linuxadmin_password" {
  length           = 32
  special          = true
  override_special = "-_"
}

resource "random_password" "os_appuser_password" {
  length           = 32
  special          = true
  override_special = "-_"
}

module "ec2" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 5.6"

  name = var.name

  ami           = var.ami
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  user_data = <<-EOT
#!/bin/bash
set -e

# Setup Secure OS Users
useradd -m -s /bin/bash linuxadmin
echo '$${random_password.os_linuxadmin_password.result}' | passwd --stdin linuxadmin
usermod -aG wheel linuxadmin
echo "linuxadmin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/linuxadmin

useradd -m -s /bin/bash appuser
echo '$${random_password.os_appuser_password.result}' | passwd --stdin appuser

# Enable Password Authentication for SSH so Vault can connect
cat << 'EOF_SSH' > /etc/ssh/sshd_config.d/00-force-password-auth.conf
PasswordAuthentication yes
KbdInteractiveAuthentication yes
PubkeyAuthentication yes
UsePAM yes
Match Address *
    PasswordAuthentication yes
EOF_SSH

# Forcefully purge negations from existing files
sed -i 's/^[#]*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sed -i 's/^[#]*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config.d/*.conf || true
systemctl restart sshd

# --- Execute Custom Application User Data ---
$${var.custom_user_data}
EOT

  user_data_replace_on_change = true

  associate_public_ip_address = var.associate_public_ip_address
  vpc_security_group_ids      = concat([module.sg.security_group_id], var.additional_security_group_ids)
  iam_instance_profile        = aws_iam_instance_profile.this.name

  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }
}

# ------------------------------------------------------------------------------
# VAULT OS REGISTRATION
# ------------------------------------------------------------------------------

resource "time_sleep" "wait_for_ec2" {
  depends_on = [module.ec2]

  # Ensure the sleep timer restarts anytime the EC2 instance ID changes
  triggers = {
    ec2_id = module.ec2.id
  }

  create_duration = "300s"
}

resource "vault_os_secret_backend_host" "this" {
  depends_on = [time_sleep.wait_for_ec2]
  namespace  = var.vault_namespace
  mount      = var.vault_os_mount_path
  name       = var.name

  address         = var.associate_public_ip_address ? module.ec2.public_ip : module.ec2.private_ip
  port            = 22
  password_policy = var.password_policy_name

  lifecycle {
    replace_triggered_by = [time_sleep.wait_for_ec2]
  }
}

resource "vault_os_secret_backend_account" "direct" {
  depends_on      = [vault_os_secret_backend_host.this]
  namespace       = var.vault_namespace
  mount           = var.vault_os_mount_path
  host            = vault_os_secret_backend_host.this.name
  name            = "linuxadmin"
  username        = "linuxadmin"
  password_wo     = random_password.os_linuxadmin_password.result
  rotation_period = var.vault_rotation_period

  lifecycle {
    replace_triggered_by = [time_sleep.wait_for_ec2]
  }
}

resource "vault_os_secret_backend_account" "child" {
  namespace          = var.vault_namespace
  mount              = var.vault_os_mount_path
  host               = vault_os_secret_backend_host.this.name
  name               = "appuser"
  username           = "appuser"
  password_wo        = random_password.os_appuser_password.result
  rotation_period    = var.vault_rotation_period
  verify_connection  = false
  parent_account_ref = vault_os_secret_backend_account.direct.name
  depends_on         = [vault_os_secret_backend_account.direct]

  lifecycle {
    replace_triggered_by = [time_sleep.wait_for_ec2]
  }
}

resource "vault_policy" "host_readers" {
  namespace = var.vault_namespace
  name      = "policy-os-$${var.name}-reader"
  policy    = <<POLICY
path "$${var.vault_os_mount_path}/hosts/$${var.name}/accounts/*/creds" {
  capabilities = ["read"]
}
POLICY
}
