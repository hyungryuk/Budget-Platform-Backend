#!/bin/bash
set -e

# Run this once on a fresh EC2 instance (Amazon Linux 2023)

# Install Docker
dnf update -y
dnf install -y docker

# Start and enable Docker service
systemctl start docker
systemctl enable docker

# Install Docker Compose plugin
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Allow ec2-user to run docker without sudo
usermod -aG docker ec2-user

# Create app directory and give ec2-user ownership
mkdir -p /app
chown ec2-user:ec2-user /app

# Install Nginx
dnf install -y nginx

# Generate self-signed SSL certificate (valid 10 years)
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/server.key \
  -out /etc/nginx/ssl/server.crt \
  -subj "/C=US/ST=State/L=City/O=Org/CN=server"

# Write Nginx config
cat > /etc/nginx/conf.d/app.conf << 'EOF'
# Redirect HTTP to HTTPS
server {
    listen 80;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name _;

    ssl_certificate     /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;
    ssl_protocols       TLSv1.2 TLSv1.3;

    location / {
        proxy_pass         http://localhost:8080;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
EOF

# Start and enable Nginx
systemctl start nginx
systemctl enable nginx

echo "Done. Nginx is running on ports 80 and 443."
echo "Docker installed. Upload docker-compose.prod.yml to /app/ and set GHCR_TOKEN."
echo "Log out and back in for docker group to take effect."
