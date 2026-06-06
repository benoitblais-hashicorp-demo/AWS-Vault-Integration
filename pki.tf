# ==============================================================================
# VAULT PUBLIC CA ORCHESTRATION (LET'S ENCRYPT)
# ==============================================================================

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

  name = "lets-encrypt-account"
  # Let's Encrypt Staging Directory (Recommended while testing to avoid rate limits)
  # Change to "https://acme-v02.api.letsencrypt.org/directory" for production certs
  directory_url  = "https://acme-staging-v02.api.letsencrypt.org/directory"
  email_contacts = ["benoit.blais@ibm.com"]
  key_type       = "rsa-2048"
}

# 3. Create the Role mapped to the allowed domain
resource "vault_pki_external_ca_secret_backend_role" "web_cert_role" {
  namespace         = vault_namespace.demo_pki.path_fq
  mount             = vault_mount.pki_ext_ca.path
  name              = "web-domain-role"
  acme_account_name = vault_pki_external_ca_secret_backend_acme_account.lets_encrypt.name

  # List the exact domain you wish to validate 
  allowed_domains = [
    "web.benoit-blais.sbx.hashidemos.io"
  ]

  allowed_domain_options = [
    "bare_domains",
    "subdomains"
  ]

  # We are relying on the DNS challenge as requested
  allowed_challenge_types = ["dns-01"]

  csr_generate_key_type     = "rsa-2048"
  csr_identifier_population = "cn_first"
}
