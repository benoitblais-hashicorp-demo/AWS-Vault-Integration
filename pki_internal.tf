# ==============================================================================
# VAULT INTERNAL PKI (PRIVATE CA)
# ==============================================================================

# 1. Mount the Internal PKI Secrets Engine
resource "vault_mount" "pki_internal" {
  namespace                 = vault_namespace.demo_pki.path_fq
  path                      = "pki-internal"
  type                      = "pki"
  description               = "Internal Root CA for benoit-blais.sbx.hashidemos.local"
  default_lease_ttl_seconds = 86400    # 1 day
  max_lease_ttl_seconds     = 31536000 # 1 year
}

# 2. Generate the Root Certificate for the Private CA
resource "vault_pki_secret_backend_root_cert" "internal_root" {
  depends_on = [vault_mount.pki_internal]
  namespace  = vault_namespace.demo_pki.path_fq
  backend    = vault_mount.pki_internal.path

  type                 = "internal"
  common_name          = "benoit-blais.sbx.hashidemos.local Root CA"
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
  allowed_domains    = ["benoit-blais.sbx.hashidemos.local"]
  allow_subdomains   = true
  allow_glob_domains = false
  allow_any_name     = false
  enforce_hostnames  = true
  generate_lease     = true
}

# ==============================================================================
# AWS PRIVATE ROUTE53 DNS MAPPING
# ==============================================================================

data "aws_route53_zone" "internal" {
  name         = "benoit-blais.sbx.hashidemos.local"
  private_zone = true
}

# Note: We will use the 'web-dynamic' naming convention in preparation
# for the standardization vs adoption architecture.
resource "aws_route53_record" "web_internal" {
  zone_id = data.aws_route53_zone.internal.zone_id
  name    = "web-dynamic.benoit-blais.sbx.hashidemos.local"
  type    = "A"
  ttl     = 300
  # Map this directly to the Private IP of our Web Server EC2 instance
  records = [module.web_dynamic.private_ip]
}
