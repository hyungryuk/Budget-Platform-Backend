#!/bin/bash
set -e

# Run this once on a fresh EC2 instance (Amazon Linux 2023)
# Usage: sudo bash setup-ec2.sh your-domain.com

DOMAIN=${1:-""}

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

# Install Nginx and Certbot
dnf install -y nginx python3-certbot-nginx

# Remove default Nginx config
rm -f /etc/nginx/conf.d/default.conf

# Write Nginx config (HTTP only first, Certbot will add HTTPS)
cat > /etc/nginx/conf.d/app.conf << EOF
server {
    listen 80;
    server_name ${DOMAIN:-_};

    location / {
        proxy_pass         http://localhost:8080;
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
    }
}
EOF

# Start and enable Nginx
systemctl start nginx
systemctl enable nginx

# Issue Let's Encrypt certificate if domain is provided
if [ -n "$DOMAIN" ]; then
  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "admin@${DOMAIN}" --no-redirect
  echo "SSL certificate issued for $DOMAIN."
  echo "Certificate auto-renews via certbot timer."
else
  echo "No domain provided — running HTTP only."
  echo "Re-run with: sudo bash setup-ec2.sh your-domain.com"
fi

echo ""
echo "Done. Nginx is running."
echo "Log out and back in for docker group to take effect."
