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

echo "Docker installed. Upload docker-compose.prod.yml to /app/ and set GHCR_TOKEN."
echo "Log out and back in for docker group to take effect."
