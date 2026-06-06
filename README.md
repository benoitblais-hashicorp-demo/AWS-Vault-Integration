<!-- BEGIN_TF_DOCS -->


## Documentation

## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.5.0)

- <a name="requirement_aws"></a> [aws](#requirement\_aws) (~> 5.0)

- <a name="requirement_random"></a> [random](#requirement\_random) (~> 3.5.0)

- <a name="requirement_time"></a> [time](#requirement\_time) (~> 0.11.0)

- <a name="requirement_vault"></a> [vault](#requirement\_vault) (>= 4.0.0)

## Modules

The following Modules are called:

### <a name="module_alb_dynamic"></a> [alb\_dynamic](#module\_alb\_dynamic)

Source: app.terraform.io/benoitblais-hashicorp/alb/aws

Version: 0.0.1

### <a name="module_alb_dynamic_sg"></a> [alb\_dynamic\_sg](#module\_alb\_dynamic\_sg)

Source: app.terraform.io/benoitblais-hashicorp/security-group/aws

Version: 0.0.2

### <a name="module_db_dynamic_sg"></a> [db\_dynamic\_sg](#module\_db\_dynamic\_sg)

Source: terraform-aws-modules/security-group/aws

Version: ~> 5.0

### <a name="module_vpc"></a> [vpc](#module\_vpc)

Source: app.terraform.io/benoitblais-hashicorp/vpc/aws

Version: 0.0.1

### <a name="module_web_dynamic"></a> [web\_dynamic](#module\_web\_dynamic)

Source: terraform-aws-modules/ec2-instance/aws

Version: ~> 5.6

### <a name="module_web_dynamic_sg"></a> [web\_dynamic\_sg](#module\_web\_dynamic\_sg)

Source: app.terraform.io/benoitblais-hashicorp/security-group/aws

Version: 0.0.2

## Required Inputs

The following input variables are required:

### <a name="input_vault_address"></a> [vault\_address](#input\_vault\_address)

Description: The URL of your Vault instance

Type: `string`

### <a name="input_vault_token"></a> [vault\_token](#input\_vault\_token)

Description: Vault token with administrative privileges

Type: `string`

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region)

Description: The AWS region to deploy resources into.

Type: `string`

Default: `"ca-central-1"`

### <a name="input_vault_server_ip"></a> [vault\_server\_ip](#input\_vault\_server\_ip)

Description: The public IP address of the Vault server allowed to access the RDS database.

Type: `string`

Default: `"3.86.9.84"`

### <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr)

Description: The CIDR block for the VPC.

Type: `string`

Default: `"10.0.0.0/16"`

## Resources

The following resources are used by this module:

- [aws_acm_certificate.web](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) (resource)
- [aws_db_instance.db_dynamic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) (resource)
- [aws_db_subnet_group.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) (resource)
- [aws_iam_instance_profile.ssm_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) (resource)
- [aws_iam_role.ssm_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) (resource)
- [aws_iam_role_policy_attachment.ssm_core](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) (resource)
- [aws_lb_target_group_attachment.web_server](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) (resource)
- [aws_route53_record.acme_challenge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) (resource)
- [aws_route53_record.web](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) (resource)
- [aws_route53_record.web_internal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) (resource)
- [random_password.db_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) (resource)
- [random_password.os_appuser_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) (resource)
- [random_password.os_linuxadmin_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) (resource)
- [time_sleep.wait_for_web_dynamic](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) (resource)
- [vault_database_secret_backend_connection.postgres](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/database_secret_backend_connection) (resource)
- [vault_database_secret_backend_role.webapp](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/database_secret_backend_role) (resource)
- [vault_mount.db](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/mount) (resource)
- [vault_mount.os_mount](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/mount) (resource)
- [vault_mount.pki_ext_ca](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/mount) (resource)
- [vault_mount.pki_internal](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/mount) (resource)
- [vault_namespace.db](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/namespace) (resource)
- [vault_namespace.demo](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/namespace) (resource)
- [vault_namespace.demo_pki](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/namespace) (resource)
- [vault_os_secret_backend.os_backend](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/os_secret_backend) (resource)
- [vault_os_secret_backend_account.child](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/os_secret_backend_account) (resource)
- [vault_os_secret_backend_account.direct](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/os_secret_backend_account) (resource)
- [vault_os_secret_backend_host.web_server](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/os_secret_backend_host) (resource)
- [vault_password_policy.strict](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/password_policy) (resource)
- [vault_pki_external_ca_secret_backend_acme_account.lets_encrypt](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/pki_external_ca_secret_backend_acme_account) (resource)
- [vault_pki_external_ca_secret_backend_order.web](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/pki_external_ca_secret_backend_order) (resource)
- [vault_pki_external_ca_secret_backend_order_certificate.web](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/pki_external_ca_secret_backend_order_certificate) (resource)
- [vault_pki_external_ca_secret_backend_order_challenge_fulfilled.dns](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/pki_external_ca_secret_backend_order_challenge_fulfilled) (resource)
- [vault_pki_external_ca_secret_backend_role.web_cert_role](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/pki_external_ca_secret_backend_role) (resource)
- [vault_pki_secret_backend_role.internal_web](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/pki_secret_backend_role) (resource)
- [vault_pki_secret_backend_root_cert.internal_root](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/pki_secret_backend_root_cert) (resource)
- [vault_policy.host_readers](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/policy) (resource)
- [vault_policy.webapp_db_policy](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/policy) (resource)
- [aws_ami.rhel9](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) (data source)
- [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) (data source)
- [aws_route53_zone.demo](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) (data source)
- [aws_route53_zone.internal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) (data source)
- [vault_pki_external_ca_secret_backend_order_challenge.dns](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/data-sources/pki_external_ca_secret_backend_order_challenge) (data source)

## Outputs

The following outputs are exported:

### <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name)

Description: The DNS name of the Application Load Balancer.

### <a name="output_linuxadmin_password"></a> [linuxadmin\_password](#output\_linuxadmin\_password)

Description: The auto-generated initial password for the linuxadmin OS user

### <a name="output_rds_endpoint"></a> [rds\_endpoint](#output\_rds\_endpoint)

Description: The endpoint of the RDS instance

### <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id)

Description: The ID of the VPC.

### <a name="output_web_dynamic_id"></a> [web\_dynamic\_id](#output\_web\_dynamic\_id)

Description: The instance ID of the web server.

### <a name="output_web_dynamic_public_ip"></a> [web\_dynamic\_public\_ip](#output\_web\_dynamic\_public\_ip)

Description: The public IP of the web server

### <a name="output_website_url"></a> [website\_url](#output\_website\_url)

Description: The final secured URL of your application

<!-- markdownlint-enable -->
<!-- END_TF_DOCS -->