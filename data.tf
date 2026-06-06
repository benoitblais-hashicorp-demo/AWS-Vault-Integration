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