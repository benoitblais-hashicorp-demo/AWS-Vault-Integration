# HashiCorp Vault Integrations on AWS

This repository provides an end-to-end Terraform architecture demonstrating HashiCorp Vault integrations on AWS. It orchestrates core AWS infrastructure (VPC, EC2, RDS, ALB) and contrasts a typical static adoption methodology against a fully standardized, dynamic Vault architecture.

## What this demo demonstrates

This demo showcases the power of HashiCorp Vault in centralizing and automating secret management across both infrastructure and applications. By comparing a static deployment to a dynamic one, it highlights the transition from long-lived, hardcoded credentials to ephemeral, Vault-managed secrets dynamically injected securely into workloads.

## Key Integration Points

* **Vault OS Secrets Engine**: Dynamic, time-to-live (TTL) bound SSH credentials for EC2 instances.
* **Vault Database Secrets Engine**: Ephemeral PostgreSQL database credentials to ensure zero-trust database access.
* **Vault PKI (Public & Private)**: Automated ACME Let's Encrypt certificate generation for public ALB endpoints via Route53 DNS challenges, and Private Root CA initialization for End-to-End Encryption between the Application Load Balancer and specific EC2 workloads.
* **HashiCorp Terraform**: Standardized infrastructure-as-code modules for AWS deployments (VPC, EC2, ALB, RDS, Security Groups).

## Demo Components

* **Network Architecture**: Foundational AWS VPC, Public/Private Subnets, and NAT Gateway.
* **Web Application (Dynamic)**: An EC2 instance running a Python Flask application that fetches database parameters.
* **Web Application (Static)**: A baseline deployment mimicking traditional manual AWS configuration (Coming soon).
* **Database**: AWS RDS PostgreSQL instance serving as the application backend.
* **Load Balancing & DNS**: Application Load Balancer securing incoming internet traffic using Vault-minted certificates, mapped via Route53.

## How this demo works

Terraform provisions the AWS networking and compute infrastructure. For the dynamic track, it automatically bootstraps the Vault environment, mounting the PKI, OS, and Database Secret engines. The EC2 web server starts up and dynamically connects to the PostgreSQL RDS database using parameters injected via Terraform/Vault, serving a web UI with verified TLS certificates.

## Demo Value Proposition

1. **Zero Trust Security**: Eliminates static, long-lived SSH keys and database passwords.
2. **Automated Certificate Lifecycle**: Drastically reduces the operational overhead of PKI renewal and provisioning.
3. **Standardization**: Illustrates the shift from disparate, manual AWS resource creation to modular, scalable Terraform code managing Vault integrations seamlessly.

## How to Conduct the Demo

1. **Showcase the Web App:**
   Navigate to the `website_url` output (e.g. `https://web-dynamic.benoit-blais.sbx.hashidemos.io`) to show the secured application running correctly with valid Let's Encrypt certificates.
2. **Demonstrate Dynamic OS Access:**
   * In the Vault UI or via CLI, request a dynamic credential for the Linux admin user: `vault read -namespace=demo_os_secret os/hosts/web-dynamic/accounts/linuxadmin`
   * Retrieve the generated username and one-time password.
   * SSH into the EC2 instance using the public IP and authenticate with this temporary credential.
3. **Demonstrate Automated Certificate Rotation:**
   * Show that the application is running via ALB using the Let's Encrypt certificate.
   * To prove internal End-to-End Encryption rotation, open your terminal and run this command against the EC2 instance directly to view its certificate validity:
     ```bash
     echo | openssl s_client -showcerts -servername web-dynamic.benoit-blais.sbx.hashidemos.local -connect <web_dynamic_public_ip>:443 2>/dev/null | openssl x509 -inform pem -noout -text | grep -A 2 "Validity"
     ```
   * Wait 5 minutes and run the command again. You will see the "Not Before" and "Not After" times shift forward exactly 5 minutes, proving Vault Agent is actively rotating the internal TLS certificates without human intervention.
4. **Demonstrate Automated OS Password Rotation:**
   * In the Vault UI, navigate to the `demo_os_secret` backend and optionally trigger a force rotation of the `linuxadmin` parent account.
   * Alternately, wait 5 minutes.
   * Attempt to SSH using the previously retrieved dynamic credential. The connection will be rejected since Vault has automatically rolled the local Linux user password seamlessly in the background (configured for an aggressive 300s / 5-minute rotation period for the demo).
5. **Demonstrate Dynamic Database Credentials:**
   * *Prerequisite*: Add your laptop IP to the Terraform `admin_laptop_ip` variable to allow external DB connections.
   * Request a temporary database credential: `vault read demo_database/creds/webapp`
   * Connect directly to the AWS RDS instance using these credentials (e.g., using `psql`, PGAdmin or DBeaver). Provide the RDS Endpoint output from Terraform as the host.
   * Update a record in the `demo_content` table to showcase real-time read/write access:

     ```sql
     UPDATE demo_content SET message = 'Live Vault Demo Successful!' WHERE id = 1;
     ```

   * Reload the web page to show the live database update.
6. **Wait for Expiration:**
   * Wait a few minutes for the TTL to expire (the default demo database lease is an ultra-short **300s / 5 minutes**), or actively revoke the lease in Vault to forcefully bypass the timer.
   * Attempt to connect to the database again using the identical dynamic credentials. Access will be explicitly denied, proving zero-trust enforcement.

## Expected Behavior

* The web server will output a success message pulling live data from the database.
* You will be able to retrieve temporary passwords from Vault.
* Direct database and OS access using expired Vault passwords will be explicitly denied.

## Permissions & Authentication

### AWS Provider

To provision resources on AWS, Terraform requires authentication. You can authenticate using any of the standard methods supported by the AWS Provider.

* **OIDC via HCP Terraform (Recommended)**: For VCS-driven workflows, configure HCP Terraform to use Dynamic Provider Credentials to assume an AWS IAM role.
* **Environment Variables**: Export standard AWS credentials for local debugging.

  ```bash
  export AWS_ACCESS_KEY_ID="anaccesskey"
  export AWS_SECRET_ACCESS_KEY="asecretkey"
  export AWS_SESSION_TOKEN="asessiontoken" # optional
  export AWS_REGION="ca-central-1"
  ```

* **Shared Credentials File**: Use an AWS profile defined in `~/.aws/credentials`.

**Required IAM Permissions**: The role or user must have sufficient rights to manage VPCs, Subnets, EC2 Instances, Route53 Zones/Records, Application Load Balancers, Target Groups, ACM Certificates, IAM Roles/Profiles, and RDS instances.

### Vault Provider

The `vault` provider must be configured to communicate with your HashiCorp Vault cluster.

* **HCP Terraform / JWT Auth (Recommended)**: Configure Vault to trust HCP Terraform workspace identities via JWT authentication.
* **Environment Variables**: Provide the Vault address and token for local runs.

  ```bash
  export VAULT_ADDR="https://vault.example.com:8200"
  export VAULT_TOKEN="hvs.abc123def456"
  ```

**Required Vault Permissions**: The token must be attached to a policy granting administrative rights to mount secret engines (`sys/mounts/*`), configure `pki`, `pki-external-ca`, `os`, and `database` engines, and create corresponding roles and policies.
