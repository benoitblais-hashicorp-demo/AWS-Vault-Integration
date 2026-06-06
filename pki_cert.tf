data "aws_route53_zone" "demo" {
  name = "benoit-blais.sbx.hashidemos.io"
}

# 4. Initiate the ACME Certificate Order
resource "vault_pki_external_ca_secret_backend_order" "web" {
  namespace   = vault_namespace.demo_pki.path_fq
  mount       = vault_mount.pki_ext_ca.path
  role_name   = vault_pki_external_ca_secret_backend_role.web_cert_role.name
  identifiers = ["web-dynamic.benoit-blais.sbx.hashidemos.io"]
}

# 5. Retrieve the DNS-01 challenge instructions from Vault
data "vault_pki_external_ca_secret_backend_order_challenge" "dns" {
  namespace      = vault_namespace.demo_pki.path_fq
  mount          = vault_pki_external_ca_secret_backend_order.web.mount
  role_name      = vault_pki_external_ca_secret_backend_order.web.role_name
  order_id       = vault_pki_external_ca_secret_backend_order.web.order_id
  challenge_type = "dns-01"
  identifier     = "web-dynamic.benoit-blais.sbx.hashidemos.io"
}

# 6. Create the TXT Record in AWS Route53 automatically via Terraform
resource "aws_route53_record" "acme_challenge" {
  zone_id = data.aws_route53_zone.demo.zone_id
  name    = "_acme-challenge.web-dynamic.benoit-blais.sbx.hashidemos.io"
  type    = "TXT"
  ttl     = 60
  records = [data.vault_pki_external_ca_secret_backend_order_challenge.dns.key_authorization]
}

# 7. Notify Let's Encrypt (Via Vault) that the record is published
resource "vault_pki_external_ca_secret_backend_order_challenge_fulfilled" "dns" {
  depends_on = [aws_route53_record.acme_challenge]

  namespace      = vault_namespace.demo_pki.path_fq
  mount          = vault_pki_external_ca_secret_backend_order.web.mount
  role_name      = vault_pki_external_ca_secret_backend_order.web.role_name
  order_id       = vault_pki_external_ca_secret_backend_order.web.order_id
  challenge_type = "dns-01"
  identifier     = "web-dynamic.benoit-blais.sbx.hashidemos.io"
}

# 8. Fetch the Final Signed Certificate securely from Vault
resource "vault_pki_external_ca_secret_backend_order_certificate" "web" {
  depends_on = [vault_pki_external_ca_secret_backend_order_challenge_fulfilled.dns]

  namespace = vault_namespace.demo_pki.path_fq
  mount     = vault_pki_external_ca_secret_backend_order.web.mount
  role_name = vault_pki_external_ca_secret_backend_order.web.role_name
  order_id  = vault_pki_external_ca_secret_backend_order.web.order_id
}

# 9. Upload the Let's Encrypt Certificate into AWS Certificate Manager
resource "aws_acm_certificate" "web" {
  private_key       = vault_pki_external_ca_secret_backend_order_certificate.web.private_key
  certificate_body  = vault_pki_external_ca_secret_backend_order_certificate.web.certificate
  certificate_chain = join("\n", vault_pki_external_ca_secret_backend_order_certificate.web.ca_chain)

  tags = {
    Name = "vault-acme-cert"
  }
}

# 10. Map your website DNS to the AWS Load Balancer
resource "aws_route53_record" "web" {
  zone_id = data.aws_route53_zone.demo.zone_id
  name    = "web-dynamic.benoit-blais.sbx.hashidemos.io"
  type    = "A"

  alias {
    name                   = module.alb_dynamic.dns_name
    zone_id                = module.alb_dynamic.zone_id
    evaluate_target_health = true
  }
}
