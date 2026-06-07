moved {
  from = aws_route53_record.acme_challenge
  to   = aws_route53_record.acme_challenge_dynamic
}
moved {
  from = aws_acm_certificate.web
  to   = aws_acm_certificate.web_dynamic
}
moved {
  from = aws_route53_record.web
  to   = aws_route53_record.web_dynamic
}
moved {
  from = aws_route53_record.web_internal
  to   = aws_route53_record.web_internal_dynamic
}
moved {
  from = aws_iam_role.ssm_role
  to   = aws_iam_role.ssm_role_dynamic
}
moved {
  from = aws_iam_role_policy_attachment.ssm_core
  to   = aws_iam_role_policy_attachment.ssm_core_dynamic
}
moved {
  from = aws_iam_instance_profile.ssm_profile
  to   = aws_iam_instance_profile.ssm_profile_dynamic
}
moved {
  from = random_password.os_linuxadmin_password
  to   = random_password.os_linuxadmin_password_dynamic
}
moved {
  from = random_password.os_appuser_password
  to   = random_password.os_appuser_password_dynamic
}
moved {
  from = aws_db_subnet_group.public
  to   = aws_db_subnet_group.dynamic
}
moved {
  from = random_password.db_password
  to   = random_password.db_password_dynamic
}
