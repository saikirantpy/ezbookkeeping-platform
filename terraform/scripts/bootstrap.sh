#!/bin/bash

set -e

echo "===================================="
echo "Starting Bootstrap Script"
echo "===================================="

dnf update -y

echo "Installing Git..."
dnf install -y git

echo "Installing Docker..."
dnf install -y docker

systemctl enable docker
systemctl start docker

usermod -aG docker ec2-user

echo "Installing Docker Compose..."

mkdir -p /usr/local/lib/docker/cli-plugins

curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
-o /usr/local/lib/docker/cli-plugins/docker-compose

chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

echo "===================================="
echo "Verification"
echo "===================================="

git --version

docker --version

docker compose version

systemctl is-active docker

echo "Bootstrap Completed Successfully"