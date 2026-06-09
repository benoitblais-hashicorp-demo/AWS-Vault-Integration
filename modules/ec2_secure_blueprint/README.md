# AWS Secure EC2 Blueprint Terraform Module

Terraform module to provision an Amazon Web Services (AWS) EC2 Instance while simultaneously registering its host connectivity and OS accounts into a HashiCorp Vault OS Secrets Engine for fully automated, dynamic password rotation.

It solves "Secret Zero" for system administrators by natively bootstrapping the initial EC2 passwords within Terraform, securely handing those initial values directly to the Vault Provider, and letting Vault seamlessly take over the SSH credential lifecycle moving forward.

## Permissions

To provision the AWS resources managed by this module, the IAM role or user running Terraform needs permissions such as:

- `AmazonEC2FullAccess` (or fine-grained privileges to manage EC2 instances, Security Groups, and network interfaces).
- `IAMFullAccess` (or fine-grained privileges to manage IAM Roles, Policies, and Instance Profiles for Systems Manager).

The Vault Provider token requires permissions to:
- Write host records and accounts to the configured Vault OS Secret Engine (`vault-plugin-secrets-os`).
- Read and manage the Vault namespace where the engine is mounted.

## Authentications

Authentication to AWS and Vault can be configured using one of the following methods, with preference given to OIDC and dynamic provider credentials in CI/CD environments.

### HCP Terraform / Terraform Enterprise Dynamic Credentials (OIDC)

Use dynamic provider credentials via OpenID Connect (OIDC) for secure, short-lived credentials when running in HCP Terraform or Terraform Enterprise.

- **Using environment variables (HCP Terraform Workspace)**
  
  - `TFC_AWS_PROVIDER_AUTH=true`
  - `TFC_AWS_RUN_ROLE_ARN=<aws-iam-role-arn>`
  - `TFC_VAULT_PROVIDER_AUTH=true`
  - `TFC_VAULT_RUN_ROLE=<vault-jwt-role>`

### Static Credentials

For local development or environments not supporting OIDC, use static tokens and access keys.

- **Using environment variables**

  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_DEFAULT_REGION`
  - `VAULT_ADDR`
  - `VAULT_TOKEN`

## Features

- Fully automated HashiCorp Vault OS Secrets Engine integration (Zero Trust SSH).
- Enforces AWS Systems Manager (SSM) natively via IAM Instance Profiles.
- Enforces AWS EC2 IMDSv2 (Instance Metadata Service Version 2) by default.
- Robust state synchronization mapping Terraform lifecycles to Vault host registration so instances recreate flawlessly.
- Customizable inline `user_data` execution payload executed post-Vault bootstrapping.
- Modular security group attachments mapping.

## Usage example

```hcl
module "secure_ec2" {
  source = "./modules/ec2_secure_blueprint"

  name                        = "app-server-01"
  ami                         = "ami-1234567890abcdef0"
  instance_type               = "t3.small"
  vpc_id                      = "vpc-12345678"
  subnet_id                   = "subnet-12345678"
  associate_public_ip_address = false

  # Optional rules for the dedicated EC2 security group
  ingress_with_source_security_group_id = [
    {
      rule                     = "https-443-tcp"
      source_security_group_id = module.alb_sg.security_group_id
    }
  ]

  # Vault Integration (Requires Vault provider and an existing OS Secrets Engine)
  vault_namespace       = "admin/my-namespace"
  vault_os_mount_path   = "os"
  password_policy_name  = "strict-rhel-policy"
  vault_rotation_period = 86400 # Rotate passwords every 24 hours
}
```

## Documentation

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
