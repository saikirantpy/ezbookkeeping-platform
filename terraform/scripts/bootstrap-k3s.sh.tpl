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

echo "Step 2 - Installing Git and Docker..."

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
# Step 4 - Docker Permissions
########################################################

echo "Step 4 - Configuring Docker permissions..."

usermod -aG docker ec2-user

########################################################
# Step 5 - Configure Swap
########################################################

echo "Step 5 - Configuring Swap..."

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
# Step 6 - Clone Repository
########################################################

echo "Step 6 - Cloning GitHub Repository..."

cd /home/ec2-user

if [ ! -d "ezbookkeeping-platform" ]; then
    git clone --branch ${github_branch} ${github_repository}
else
    echo "Repository already exists. Pulling latest changes..."
    cd ezbookkeeping-platform
    git pull
fi

chown -R ec2-user:ec2-user /home/ec2-user/ezbookkeeping-platform

########################################################
# Step 7 - Install k3s
########################################################

echo "Step 7 - Installing k3s..."

curl -sfL https://get.k3s.io | sh -

echo "Waiting for k3s..."

until kubectl get nodes >/dev/null 2>&1; do
    sleep 5
done

echo "k3s Installed Successfully."

########################################################
# Step 8 - Configure kubectl
########################################################

echo "Step 8 - Configuring kubectl..."

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

mkdir -p /home/ec2-user/.kube

cp /etc/rancher/k3s/k3s.yaml /home/ec2-user/.kube/config

chown -R ec2-user:ec2-user /home/ec2-user/.kube

chmod 600 /home/ec2-user/.kube/config

########################################################
# Step 9 - Deploy Application
########################################################

echo "Step 9 - Deploying Application..."

cd /home/ec2-user/ezbookkeeping-platform

kubectl apply -f k3s/namespace.yaml

kubectl apply -f k3s/secret.yaml

kubectl apply -f k3s/configmap.yaml

kubectl apply -f k3s/postgres-pvc.yaml
kubectl apply -f k3s/app-pvc.yaml

kubectl apply -f k3s/postgres-service.yaml
kubectl apply -f k3s/postgres-deployment.yaml

kubectl apply -f k3s/ezbookkeeping-service.yaml
kubectl apply -f k3s/ezbookkeeping-deployment.yaml

kubectl apply -f k3s/ingress.yaml

########################################################
# Step 10 - Wait for Pods
########################################################

echo "Step 10 - Waiting for Pods..."

kubectl wait \
  --for=condition=Ready pod \
  --all \
  -n ezbookkeeping \
  --timeout=300s

########################################################
# Step 11 - Verification
########################################################

echo
echo "===================================="
echo "Cluster Verification"
echo "===================================="

kubectl get nodes

echo

kubectl get pods -n ezbookkeeping

echo

kubectl get svc -n ezbookkeeping

echo

kubectl get ingress -n ezbookkeeping

echo

kubectl get pvc -n ezbookkeeping

########################################################
# Step 12 - Installed Versions
########################################################

echo
echo "===================================="
echo "Installed Versions"
echo "===================================="

docker --version

git --version

kubectl version --client

k3s --version

echo
echo "===================================="
echo "Bootstrap Completed Successfully"
echo "===================================="