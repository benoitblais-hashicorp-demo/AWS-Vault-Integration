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
resource "vault_mount" "os_mount" {
  namespace = vault_namespace.demo.path_fq
  path      = "os"
  # Use the canonical plugin name. If the plugin is registered differently 
  # in your root catalog, you configure it here.
  type        = "vault-plugin-secrets-os"
  description = "OS secret backend"
}

resource "vault_os_secret_backend" "os_backend" {
  namespace                       = vault_namespace.demo.path_fq
  mount                           = vault_mount.os_mount.path
  ssh_host_key_trust_on_first_use = true
}

resource "time_sleep" "wait_for_web_server" {
  depends_on      = [module.web_server]
  create_duration = "240s"
}

# 3. REGISTER HOSTS
resource "vault_os_secret_backend_host" "web_server" {
  depends_on = [time_sleep.wait_for_web_server]
  namespace  = vault_namespace.demo.path_fq
  mount      = vault_os_secret_backend.os_backend.mount
  name       = "web-server"
  # Using the public IP of the created web server so external Vault can reach it
  address         = module.web_server.public_ip
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

# VAULT DATABASE SECRETS ENGINE (POSTGRESQL)
# ==========================================

resource "vault_namespace" "db" {
  path = "demo_database"
}

# 1. Mount the Database Secrets Engine
resource "vault_mount" "db" {
  namespace   = vault_namespace.db.path_fq
  path        = "database"
  type        = "database"
  description = "Dynamic credentials for AWS RDS PostgreSQL"
}

# 2. Configure the PostgreSQL Database Connection
resource "vault_database_secret_backend_connection" "postgres" {
  namespace     = vault_namespace.db.path_fq
  backend       = vault_mount.db.path
  name          = "aws-rds-postgres"
  allowed_roles = ["readonly", "webapp"]

  postgresql {
    connection_url = "postgresql://{{username}}:{{password}}@${aws_db_instance.postgres.endpoint}/${aws_db_instance.postgres.db_name}"
    username       = aws_db_instance.postgres.username
    password       = aws_db_instance.postgres.password
  }
}

# 3. Create a Role for dynamically generated App credentials (Read/Write)
resource "vault_database_secret_backend_role" "webapp" {
  namespace = vault_namespace.db.path_fq
  backend   = vault_mount.db.path
  name      = "webapp"
  db_name   = vault_database_secret_backend_connection.postgres.name
  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT SELECT, UPDATE, INSERT, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";"
  ]
  default_ttl = 3600  # 1 hour
  max_ttl     = 86400 # 24 hours
}

# 4. Create an ACL policy to allow the application to generate these dynamic credentials
resource "vault_policy" "webapp_db_policy" {
  namespace = vault_namespace.db.path_fq
  name      = "webapp-database-policy"
  policy    = <<POLICY
# Allow generating dynamic database credentials
path "database/creds/webapp" {
  capabilities = ["read"]
}
POLICY
}
