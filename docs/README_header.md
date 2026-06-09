# HashiCorp Vault Integrations on AWS

This repository provides an end-to-end Terraform architecture demonstrating HashiCorp Vault integrations on AWS. It orchestrates core AWS infrastructure (VPC, EC2, RDS, ALB) and contrasts a typical static adoption methodology against a fully standardized, dynamic Vault architecture.

## What this demo demonstrates

This demo showcases the power of HashiCorp Vault in centralizing and automating secret management across both infrastructure and applications. By comparing a static deployment to a dynamic one, it highlights the transition from long-lived, hardcoded credentials to ephemeral, Vault-managed secrets dynamically injected securely into workloads.

## Features

* **Machine Identity (AWS IAM Auth)**: Seamless, secure authentication to Vault leveraging native AWS EC2 IAM Instance Profiles—eliminating the need to bootstrap servers with secret tokens.
* **Vault OS Secrets Engine**: Dynamic, time-to-live (TTL) bound SSH credentials for EC2 instances.
* **Vault Database Secrets Engine**: Ephemeral PostgreSQL database credentials to ensure zero-trust database access.
* **Vault PKI (Public & Private)**: Automated ACME Let's Encrypt certificate generation for public ALB endpoints via Route53 DNS challenges, and Private Root CA initialization for End-to-End Encryption between the Application Load Balancer and specific EC2 workloads.
* **HashiCorp Terraform**: Standardized infrastructure-as-code modules for AWS deployments (VPC, EC2, ALB, RDS, Security Groups).

## Demo Components

* **Network Architecture**: Foundational AWS VPC, Public/Private Subnets, and NAT Gateway.
* **Web Application (Dynamic)**: An EC2 instance securely bootstrapped using Vault dynamically injected credentials, with TLS auto-rotation.
* **Web Application (Static)**: A baseline deployment mimicking traditional manual AWS configuration, storing long-lived generic credentials in AWS Secrets Manager and offloading public certificates to native AWS ACM.
* **Databases**: Parallel AWS RDS PostgreSQL instances serving as the application backend for both tracks.
* **Load Balancing & DNS**: Application Load Balancers securing incoming internet traffic, mapped via Route53.

## How this demo works

Terraform provisions the AWS networking and compute infrastructure. For the dynamic track, it automatically bootstraps the Vault environment, mounting the PKI, OS, and Database Secret engines. The EC2 web server starts up and dynamically connects to the PostgreSQL RDS database using parameters injected via Terraform/Vault, serving a web UI with verified TLS certificates.

## Demo Value Proposition

1. **Zero Trust Security**: Eliminates static, long-lived SSH keys and database passwords.
2. **Automated Certificate Lifecycle**: Drastically reduces the operational overhead of PKI renewal and provisioning.
3. **Machine Identity Integration**: Removes the "Secret Zero" problem by using innate cloud identities (AWS IAM) for seamless, passwordless Vault authentication from the EC2 instance.
4. **Standardization**: Illustrates the shift from disparate, manual AWS resource creation to modular, scalable Terraform code managing Vault integrations seamlessly.

## How to Conduct the Demo

*Prerequisite*: Add your laptop IP to the Terraform `admin_laptop_ip` variable to allow external SSH and database connections through the AWS Security Groups.

### Part 1: The Static Track (Traditional Secret Management)

1. **Showcase the Static Web App:**
   Navigate to the `website_url_static` output to view the static application. Inspect the certificate in your browser to show it was natively issued by Amazon (ACM) and terminates at the Load Balancer level.
2. **Investigate the Static Infrastructure Secrets:**
   * Retrieve the static OS credential from AWS Secrets Manager using the ARN provided in the Terraform outputs (either via the AWS Console or using the AWS CLI):

     ```bash
     aws secretsmanager get-secret-value --secret-id <secrets_manager_os_arn>
     ```

   * SSH into the static EC2 instance (`web_static_public_ip`) using the `linuxadmin` user and the retrieved static password.
3. **Expose Hardcoded Application Credentials:**
   * While connected to the EC2 instance via SSH, inspect the application source code:

     ```bash
     cat /opt/app/app.py
     ```

   * Point out the exact database credentials (username and password script block) completely hardcoded in plain-text inside the application code. This demonstrates the inherent risks of static secret distribution at provisioning time.
4. **Access the Database with Static Credentials:**
   * Retrieve the static database credentials from Secrets Manager:

     ```bash
     aws secretsmanager get-secret-value --secret-id <secrets_manager_db_arn>
     ```

   * Connect to the static RDS instance (using the `rds_endpoint_static` output as the host).
   * Update the table just as you will in the dynamic demo:

     ```sql
     UPDATE demo_content SET message = 'Static Manual Demo Update Successful!' WHERE id = 1;
     ```

   * Highlight that access remains permanently open to whoever holds this static credential until a human manually rotates it and restarts all dependent applications.

### Part 2: The Dynamic Track (HashiCorp Vault Integration)

1. **Showcase the Dynamic Web App:**
   Navigate to the `website_url` output (e.g. `https://web-dynamic.benoit-blais.sbx.hashidemos.io`) to show the secured application running correctly with valid Let's Encrypt certificates natively orchestrated by Vault.
2. **Demonstrate Dynamic OS Access:**
   * In the Vault UI, navigate to the `demo_os_secret` namespace to show the OS secret engine mount path.
   * From the Vault CLI, show the managed host: `vault list os/hosts`
   * Request a dynamic credential for the Linux admin user: `vault read os/hosts/web-dynamic/accounts/linuxadmin/creds`
   * Retrieve the generated username and one-time password.
   * SSH into the EC2 instance using the public IP and authenticate with this temporary credential.
3. **Demonstrate Automated Certificate Rotation:**
   * **Public Certificate (Let's Encrypt)**: Show that the application is directly running via the Application Load Balancer using a valid Let's Encrypt certificate.
   * In the Vault UI, navigate to the `demo_pki` namespace and view the `pki-external-ca` (Let's Encrypt) secret engine mount.
   * To demonstrate public certificate rotation, manually run the repository's configuration workflow to force the rotation of the public certificate. Point out how Terraform and Vault seamlessly orchestrate the ACME DNS-01 challenge and natively update the AWS Certificate Manager (ACM) resource.
   * **Internal Certificates (End-to-End Encryption)**: In the Vault UI, show the `pki-internal` (Root CA) secret engine mount.
   * Click into the `pki-internal` engine and view the Certificates list. Point out the high volume of certificates being continuously generated due to the Vault Agent's 5-minute rotation cycle.
   * While connected to the EC2 instance via SSH, run the following command to view the actual physical bundle managed by Vault Agent:

     ```bash
     openssl x509 -in /opt/app/bundle.pem -text -noout | grep -A 2 "Validity"
     ```

   * To prove the web server is actively serving traffic using this rapidly rotating certificate, run the following command directly on the EC2 instance to poll the local listener:

     ```bash
     curl -v --cacert /opt/app/bundle.pem https://localhost/ 2>&1 | grep "expire date"
     ```

   * Wait 5 minutes and run the commands again. You will see the "Not Before" and "Not After" times sequentially shift forward on both the file and the web server response, proving Vault Agent is fetching new TLS certificates and seamlessly restarting the web service without human intervention.
4. **Demonstrate Automated OS Password Rotation:**
   * To forcefully trigger an immediate password rotation so you don't have to wait 5 minutes, run this command from the Vault CLI: `vault write -force os/hosts/web-dynamic/accounts/linuxadmin/rotate`
   * Request the credential again to observe that the version has incremented and the password has completely changed: `vault read os/hosts/web-dynamic/accounts/linuxadmin/creds`
   * Attempt to SSH using the *first* (previously retrieved) dynamic credential. The connection will be rejected since Vault has rolled the local Linux user password seamlessly in the background (configured for an aggressive 300s / 5-minute rotation period for the demo).
   * Demonstrate that SSH access is immediately permitted when using the newly minted password.
5. **Demonstrate Dynamic Database Credentials:**
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

## Permissions

### AWS Provider Permissions

**Required IAM Permissions**: The role or user must have sufficient rights to manage VPCs, Subnets, EC2 Instances, Route53 Zones/Records, Application Load Balancers, Target Groups, ACM Certificates, IAM Roles/Profiles, and RDS instances.

### Vault Provider Permissions

**Required Vault Permissions**: The token must be attached to a policy granting administrative rights to mount secret engines (`sys/mounts/*`), configure `pki`, `pki-external-ca`, `os`, and `database` engines, and create corresponding roles and policies.

## Authentications

### AWS Provider Authentication

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

### Vault Provider Authentication

The `vault` provider must be configured to communicate with your HashiCorp Vault cluster.

* **HCP Terraform / JWT Auth (Recommended)**: Configure Vault to trust HCP Terraform workspace identities via JWT authentication.
* **Environment Variables**: Provide the Vault address and token for local runs.

  ```bash
  export VAULT_ADDR="https://vault.example.com:8200"
  export VAULT_TOKEN="hvs.abc123def456"
  ```
