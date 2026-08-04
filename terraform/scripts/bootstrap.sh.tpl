#!/bin/bash
set -Eeuo pipefail

trap 'echo "[ERROR] Line $LINENO failed with exit code $?." >&2' ERR

exec > >(tee -a /var/log/bootstrap.log) 2>&1

echo "===================================="
echo "Bootstrap Started"
echo "===================================="

########################################################
# Step 1 - Update OS
########################################################

echo "Step 1 - Updating OS..."

dnf update -y

########################################################
# Step 2 - Install Packages
########################################################

echo "Step 2 - Installing Git, Docker and Curl..."

dnf install -y git docker

########################################################
# Step 3 - Enable Docker
########################################################

echo "Step 3 - Starting Docker..."

systemctl enable docker
systemctl start docker

echo "Waiting for Docker..."

until docker info >/dev/null 2>&1; do
    sleep 2
done

echo "Docker is ready."

########################################################
# Step 4 - Add ec2-user to Docker Group
########################################################

echo "Step 4 - Configuring Docker permissions..."

usermod -aG docker ec2-user

########################################################
# Step 5 - Install Docker CLI Plugins
########################################################

echo "Step 5 - Installing Docker CLI Plugins..."

mkdir -p /usr/libexec/docker/cli-plugins

########################################################
# Create Swap (2 GB)
########################################################

echo "Step 5.1 - Configuring Swap..."

if ! swapon --show | grep -q "/swapfile"; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
    echo "Swap enabled."
else
    echo "Swap already enabled."
fi

free -h
########################################################
# Step 6 - Install Buildx
########################################################

echo "Installing Docker Buildx..."

BUILDX_VERSION=v0.36.0

curl -fsSL \
https://github.com/docker/buildx/releases/download/$${BUILDX_VERSION}/buildx-$${BUILDX_VERSION}.linux-amd64 \
-o /usr/libexec/docker/cli-plugins/docker-buildx

chmod +x /usr/libexec/docker/cli-plugins/docker-buildx

########################################################
# Step 7 - Install Docker Compose
########################################################

echo "Installing Docker Compose..."

COMPOSE_VERSION=v2.39.1

curl -fsSL \
https://github.com/docker/compose/releases/download/$${COMPOSE_VERSION}/docker-compose-linux-x86_64 \
-o /usr/libexec/docker/cli-plugins/docker-compose

chmod +x /usr/libexec/docker/cli-plugins/docker-compose

########################################################
# Step 8 - Verify Docker Plugins
########################################################

echo "Verifying Docker Plugins..."

docker buildx version
docker compose version

########################################################
# Step 9 - Clone Repository
########################################################

echo "Cloning GitHub repository..."

cd /home/ec2-user

if [ ! -d "ezbookkeeping-platform" ]; then
    git clone --branch ${github_branch} ${github_repository}
else
    echo "Repository already exists. Skipping clone."
fi

chown -R ec2-user:ec2-user /home/ec2-user/ezbookkeeping-platform

########################################################
# Step 10 - Installed Versions
########################################################

echo
echo "===================================="
echo "Installed Versions"
echo "===================================="

docker --version
git --version
docker buildx version
docker compose version

echo
echo "===================================="
echo "Bootstrap Completed Successfully"
echo "===================================="

echo
echo "NOTE:"
echo "Reconnect to the EC2 instance (or run 'newgrp docker')"
echo "before running Docker commands as ec2-user."

##Run docker compose up -d
cd /home/ec2-user/ezbookkeeping-platform

docker compose pull

docker compose up -d