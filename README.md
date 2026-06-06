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

### <a name="module_alb"></a> [alb](#module\_alb)

Source: app.terraform.io/benoitblais-hashicorp/alb/aws

Version: 0.0.1

### <a name="module_alb_sg"></a> [alb\_sg](#module\_alb\_sg)

Source: app.terraform.io/benoitblais-hashicorp/security-group/aws

Version: 0.0.2

### <a name="module_rds_sg"></a> [rds\_sg](#module\_rds\_sg)

Source: terraform-aws-modules/security-group/aws

Version: ~> 5.0

### <a name="module_vpc"></a> [vpc](#module\_vpc)

Source: app.terraform.io/benoitblais-hashicorp/vpc/aws

Version: 0.0.1

### <a name="module_web_server"></a> [web\_server](#module\_web\_server)

Source: terraform-aws-modules/ec2-instance/aws

Version: ~> 5.6

### <a name="module_web_server_sg"></a> [web\_server\_sg](#module\_web\_server\_sg)

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

- [aws_db_instance.postgres](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) (resource)
- [aws_db_subnet_group.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) (resource)
- [aws_iam_instance_profile.ssm_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) (resource)
- [aws_iam_role.ssm_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) (resource)
- [aws_iam_role_policy_attachment.ssm_core](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) (resource)
- [aws_lb_target_group_attachment.web_server](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) (resource)
- [random_password.db_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) (resource)
- [random_password.os_appuser_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) (resource)
- [random_password.os_linuxadmin_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) (resource)
- [time_sleep.wait_for_web_server](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) (resource)
- [vault_database_secret_backend_connection.postgres](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/database_secret_backend_connection) (resource)
- [vault_database_secret_backend_role.webapp](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/database_secret_backend_role) (resource)
- [vault_mount.db](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/mount) (resource)
- [vault_mount.os_mount](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/mount) (resource)
- [vault_namespace.db](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/namespace) (resource)
- [vault_namespace.demo](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/namespace) (resource)
- [vault_os_secret_backend.os_backend](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/os_secret_backend) (resource)
- [vault_os_secret_backend_account.child](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/os_secret_backend_account) (resource)
- [vault_os_secret_backend_account.direct](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/os_secret_backend_account) (resource)
- [vault_os_secret_backend_host.web_server](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/os_secret_backend_host) (resource)
- [vault_password_policy.strict](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/password_policy) (resource)
- [vault_policy.host_readers](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/policy) (resource)
- [vault_policy.webapp_db_policy](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/policy) (resource)
- [aws_ami.rhel9](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) (data source)
- [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) (data source)

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

### <a name="output_web_server_id"></a> [web\_server\_id](#output\_web\_server\_id)

Description: The instance ID of the web server.

### <a name="output_web_server_public_ip"></a> [web\_server\_public\_ip](#output\_web\_server\_public\_ip)

Description: The public IP of the web server

<!-- markdownlint-enable -->
<!-- END_TF_DOCS -->