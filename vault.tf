resource "vault_namespace" "demo" {
  path = "demo_os_secret"
}

# 1. PASSWORD POLICIES
resource "vault_password_policy" "strict" {
  namespace = vault_namespace.demo.path_fq
  name      = "rhel-strict-policy"
  policy    = <<POLICY
    length = 32
    rule "charset" {
      charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
      min-chars = 4
    }
POLICY
}

# 2. ENGINE MOUNT
resource "vault_os_secret_backend" "os_backend" {
  namespace                       = vault_namespace.demo.path_fq
  mount                           = "os"
  ssh_host_key_trust_on_first_use = true
}

# 3. REGISTER HOSTS
resource "vault_os_secret_backend_host" "web_server" {
  namespace = vault_namespace.demo.path_fq
  mount     = vault_os_secret_backend.os_backend.mount
  name      = "web-server"
  # Using the private IP of the created web server
  address         = module.web_server.private_ip
  port            = 22
  password_policy = vault_password_policy.strict.name
}

# 4. PRIVILEGED PARENT ACCOUNTS
resource "vault_os_secret_backend_account" "direct" {
  namespace       = vault_namespace.demo.path_fq
  mount           = vault_os_secret_backend.os_backend.mount
  host            = vault_os_secret_backend_host.web_server.name
  name            = "linuxadmin"
  username        = "linuxadmin"
  password_wo     = "Mp^Y#WYbf4VEfkxM^^3Lf89I"
  rotation_period = 86400
}

# 5. CHILD ACCOUNTS
resource "vault_os_secret_backend_account" "child" {
  namespace          = vault_namespace.demo.path_fq
  mount              = vault_os_secret_backend.os_backend.mount
  host               = vault_os_secret_backend_host.web_server.name
  name               = "appuser"
  username           = "appuser"
  password_wo        = "Q&EJx%xx$^rj&xSUBC5#VVgh"
  rotation_period    = 86400
  verify_connection  = false
  parent_account_ref = vault_os_secret_backend_account.direct.name
  depends_on         = [vault_os_secret_backend_account.direct]
}

# 6. TARGETED VAULT ACL POLICIES
resource "vault_policy" "host_readers" {
  namespace = vault_namespace.demo.path_fq
  name      = "policy-os-web-server-reader"
  policy    = <<POLICY
path "os/hosts/web-server/accounts/*/creds" {
  capabilities = ["read"]
}
POLICY
}