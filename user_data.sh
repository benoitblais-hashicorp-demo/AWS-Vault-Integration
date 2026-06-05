#!/bin/bash
set -e

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting RHEL Web and DB initialization..."

# 1. Update OS and install Python and PostgreSQL client
dnf update -y
dnf install -y postgresql python3 python3-pip

# 1.5 Setup Vault OS Users and SSH Password Authentication
useradd -m -s /bin/bash linuxadmin
echo "linuxadmin:Mp^Y#WYbf4VEfkxM^^3Lf89I" | chpasswd
usermod -aG wheel linuxadmin
echo "linuxadmin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/linuxadmin

useradd -m -s /bin/bash appuser
echo "appuser:Q&EJx%xx$^rj&xSUBC5#VVgh" | chpasswd

# Enable Password Authentication for SSH so Vault can connect
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config.d/*.conf || true

# Force password authentication in a drop-in file to override AWS defaults
echo "PasswordAuthentication yes" > /etc/ssh/sshd_config.d/99-force-password-auth.conf
echo "KbdInteractiveAuthentication yes" >> /etc/ssh/sshd_config.d/99-force-password-auth.conf

systemctl restart sshd

# 2. Install Flask and psycopg2 for the python web app
pip3 install Flask psycopg2-binary

# 3. Wait for the database to be reachable & Seed the Database!
export PGPASSWORD="${db_password}"
echo "Seeding the remote AWS RDS Database..."

# Create a table and insert a row if it doesn't exist
psql -h ${db_host} -p ${db_port} -U ${db_user} -d ${db_name} -c "
CREATE TABLE IF NOT EXISTS demo_content (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255),
    message TEXT
);
INSERT INTO demo_content (title, message)
SELECT 'Vault Dynamic Secrets Demo', 'This information was successfully retrieved from an AWS RDS PostgreSQL Database!'
WHERE NOT EXISTS (SELECT 1 FROM demo_content);
"

# 4. Create the Web Application
mkdir -p /opt/app
cat << 'EOF' > /opt/app/app.py
from flask import Flask
import psycopg2
import os

app = Flask(__name__)

@app.route('/')
def index():
    try:
        # In a real Vault deployment, Vault agent would write these variables dynamically
        conn = psycopg2.connect(
            host=os.environ.get('DB_HOST'),
            port=os.environ.get('DB_PORT'),
            database=os.environ.get('DB_NAME'),
            user=os.environ.get('DB_USER'),
            password=os.environ.get('DB_PASSWORD')
        )
        cur = conn.cursor()
        cur.execute("SELECT title, message FROM demo_content LIMIT 1;")
        row = cur.fetchone()
        cur.close()
        conn.close()
        
        if row:
            title, message = row
            return f"<h1>{title}</h1><p><strong>Status:</strong> {message}</p>"
        else:
            return "<h1>Hello World!</h1><p>Database connected, but no content found.</p>"
            
    except Exception as e:
        return f"<h1>Database Error</h1><p>{str(e)}</p>"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
EOF

# 5. Run the web application using SystemD
cat << 'EOF' > /etc/systemd/system/demo-web.service
[Unit]
Description=Demo Flask Web App
After=network.target

[Service]
Environment="DB_HOST=${db_host}"
Environment="DB_PORT=${db_port}"
Environment="DB_NAME=${db_name}"
Environment="DB_USER=${db_user}"
Environment="DB_PASSWORD=${db_password}"
ExecStart=/usr/bin/python3 /opt/app/app.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable demo-web
systemctl start demo-web

echo "Initialization Complete"