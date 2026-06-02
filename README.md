<!-- BEGIN_TF_DOCS -->


## Documentation

## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.5.0)

- <a name="requirement_aws"></a> [aws](#requirement\_aws) (~> 5.0)

## Modules

The following Modules are called:

### <a name="module_vpc"></a> [vpc](#module\_vpc)

Source: terraform-aws-modules/vpc/aws

Version: ~> 5.0

### <a name="module_web_server"></a> [web\_server](#module\_web\_server)

Source: terraform-aws-modules/ec2-instance/aws

Version: ~> 5.6

### <a name="module_web_server_sg"></a> [web\_server\_sg](#module\_web\_server\_sg)

Source: terraform-aws-modules/security-group/aws

Version: ~> 5.0

## Required Inputs

No required inputs.

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region)

Description: The AWS region to deploy resources into.

Type: `string`

Default: `"us-east-1"`

### <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr)

Description: The CIDR block for the VPC.

Type: `string`

Default: `"10.0.0.0/16"`

## Resources

The following resources are used by this module:

- [aws_iam_instance_profile.ssm_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) (resource)
- [aws_iam_role.ssm_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) (resource)
- [aws_iam_role_policy_attachment.ssm_core](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) (resource)
- [aws_ami.rhel9](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) (data source)
- [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) (data source)

## Outputs

The following outputs are exported:

### <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id)

Description: The ID of the VPC.

### <a name="output_web_server_id"></a> [web\_server\_id](#output\_web\_server\_id)

Description: The instance ID of the web server.

### <a name="output_web_server_public_ip"></a> [web\_server\_public\_ip](#output\_web\_server\_public\_ip)

Description: The public IP address of the web server.

<!-- markdownlint-enable -->
<!-- END_TF_DOCS -->