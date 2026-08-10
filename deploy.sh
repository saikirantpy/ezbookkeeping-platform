#!/bin/bash

set -e

###############################################
# Configuration
###############################################

AWS_REGION="ap-south-1"
LOCAL_IMAGE="306404/ezbookkeeping-platform:v3"

PROJECT_ROOT=$(cd "$(dirname "$0")" && pwd)
TF_DIR="$PROJECT_ROOT/terraform-eks"
K8S_DIR="$PROJECT_ROOT/eks"

###############################################
# Colors
###############################################

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

###############################################
# Logging
###############################################

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

###############################################
# Check Dependencies
###############################################

check_dependencies() {

    info "Checking required tools..."

    COMMANDS=(
        terraform
        kubectl
        aws
        docker
    )

    for cmd in "${COMMANDS[@]}"
    do
        if ! command -v "$cmd" >/dev/null 2>&1
        then
            error "$cmd is not installed."
            exit 1
        fi
    done

    success "All dependencies found."

}

###############################################
# Verify Local Docker Image
###############################################

check_local_image() {

    info "Checking local Docker image..."

    if ! docker image inspect "$LOCAL_IMAGE" >/dev/null 2>&1
    then
        error "Local image not found: $LOCAL_IMAGE"
        exit 1
    fi

    success "Local image found."

}
###############################################
# Terraform Apply
###############################################

terraform_apply() {

    info "Initializing Terraform..."

    cd "$TF_DIR"

    terraform init -upgrade

    info "Applying Terraform Infrastructure..."

    terraform apply \
    -auto-approve \
    -input=false \
    -var-file="terraform.tfvars"

    success "Terraform Apply Completed."

}

###############################################
# Read Terraform Outputs
###############################################

read_outputs() {

    info "Reading Terraform Outputs..."

    ECR_REPOSITORY=$(terraform output -raw ecr_repository_url)
    CLUSTER_NAME=$(terraform output -raw eks_cluster_name)

    success "Terraform Outputs Retrieved."

    echo ""
    echo "----------------------------------------"
    echo "Cluster : $CLUSTER_NAME"
    echo "ECR Repo: $ECR_REPOSITORY"
    echo "----------------------------------------"
    echo ""

}

###############################################
# Configure kubectl
###############################################

configure_kubectl() {

    info "Updating kubeconfig..."

    aws eks update-kubeconfig \
        --region "$AWS_REGION" \
        --name "$CLUSTER_NAME"

    success "kubectl configured."

}

###############################################
# Wait for EKS Nodes
###############################################

wait_for_nodes() {

    info "Waiting for Worker Nodes to become Ready..."

    ATTEMPTS=60

    until kubectl get nodes >/dev/null 2>&1
    do
        ATTEMPTS=$((ATTEMPTS-1))

        if [ $ATTEMPTS -eq 0 ]
        then
            error "Unable to connect to EKS Cluster."
            exit 1
        fi

        sleep 10
    done

    kubectl wait \
        --for=condition=Ready nodes \
        --all \
        --timeout=10m

    success "All Worker Nodes are Ready."

}

###############################################
# Verify Cluster
###############################################

verify_cluster() {

    info "Cluster Information"

    kubectl get nodes -o wide

    echo ""

}
###############################################
# Login to Amazon ECR
###############################################

login_ecr() {

    info "Logging into Amazon ECR..."

    aws ecr get-login-password \
    --region "$AWS_REGION" \
    | docker login \
        --username AWS \
        --password-stdin \
        "$(echo "$ECR_REPOSITORY" | cut -d'/' -f1)"

    success "Successfully logged into Amazon ECR."

}

###############################################
# Push Docker Image
###############################################

push_image() {

    info "Tagging Docker image..."

    docker tag \
        "$LOCAL_IMAGE" \
        "$ECR_REPOSITORY:latest"

    success "Docker image tagged."

    info "Pushing Docker image to Amazon ECR..."

    docker push \
        "$ECR_REPOSITORY:latest"

    success "Docker image pushed successfully."

}

###############################################
# Deploy Kubernetes Resources
###############################################

deploy_kubernetes() {

    info "Deploying Kubernetes Resources..."

    TMP_DIR=$(mktemp -d)

    ###########################################
    # Namespace
    ###########################################

    kubectl apply -f "$K8S_DIR/namespace.yaml"

    ###########################################
    # Secrets
    ###########################################

    kubectl apply -f "$K8S_DIR/secret.yaml"

    ###########################################
    # ConfigMap
    ###########################################

    kubectl apply -f "$K8S_DIR/configmap.yaml"

    ###########################################
    # Persistent Volume Claims
    ###########################################

    kubectl apply -f "$K8S_DIR/postgres-pvc.yaml"

    kubectl apply -f "$K8S_DIR/app-pvc.yaml"

    ###########################################
    # PostgreSQL
    ###########################################

    kubectl apply -f "$K8S_DIR/postgres-service.yaml"

    kubectl apply -f "$K8S_DIR/postgres-deployment.yaml"

    ###########################################
    # ezBookkeeping Deployment
    ###########################################

    sed \
        "s|__ECR_REPOSITORY__|$ECR_REPOSITORY|g" \
        "$K8S_DIR/ezbookkeeping-deployment.yaml" \
        > "$TMP_DIR/ezbookkeeping-deployment.yaml"

    kubectl apply \
        -f "$TMP_DIR/ezbookkeeping-deployment.yaml"

    ###########################################
    # Application Service
    ###########################################

    kubectl apply -f "$K8S_DIR/ezbookkeeping-service.yaml"

    ###########################################
    # HPA
    ###########################################

    if [ -f "$K8S_DIR/hpa.yaml" ]; then
        kubectl apply -f "$K8S_DIR/hpa.yaml"
    fi

    ###########################################
    # Ingress
    ###########################################

    if [ -f "$K8S_DIR/ingress-disabled.yaml" ]; then
        kubectl apply -f "$K8S_DIR/ingress-disabled.yaml"
    fi

    success "Kubernetes manifests deployed."

}

###############################################
# Verify Resources
###############################################

verify_resources() {

    info "Current Kubernetes Resources"

    echo ""

    kubectl get pods -n ezbookkeeping

    echo ""

    kubectl get svc -n ezbookkeeping

    echo ""

}
###############################################
# Wait for PostgreSQL
###############################################

wait_for_postgres() {

    info "Waiting for PostgreSQL..."

    kubectl rollout status \
        deployment/postgres \
        -n ezbookkeeping \
        --timeout=10m

    success "PostgreSQL is Ready."

}

###############################################
# Wait for Application
###############################################

wait_for_application() {

    info "Waiting for ezBookkeeping..."

    kubectl rollout status \
        deployment/ezbookkeeping \
        -n ezbookkeeping \
        --timeout=10m

    success "Application is Ready."

}

###############################################
# Wait for LoadBalancer
###############################################

wait_for_loadbalancer() {

    info "Waiting for LoadBalancer..."

    for i in {1..60}
    do

        HOSTNAME=$(
            kubectl get svc ezbookkeeping \
            -n ezbookkeeping \
            -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
        )

        if [ -n "$HOSTNAME" ]
        then

            success "LoadBalancer Created."

            APP_URL="http://$HOSTNAME:8080"

            return

        fi

        sleep 10

    done

    warning "LoadBalancer not ready yet."

}

###############################################
# Deployment Summary
###############################################

deployment_summary() {

    echo ""
    echo "=================================================="
    echo "Deployment Completed"
    echo "=================================================="

    echo ""

    kubectl get pods -n ezbookkeeping

    echo ""

    kubectl get svc -n ezbookkeeping

    echo ""

    if [ -n "$APP_URL" ]
    then
        echo "Application URL"
        echo ""
        echo "$APP_URL"
    fi

    echo ""
    echo "=================================================="

}

###############################################
# Cleanup
###############################################

cleanup() {

    if [ -d "$TMP_DIR" ]
    then
        rm -rf "$TMP_DIR"
    fi

}

###############################################
# Main
###############################################

main() {

    echo ""
    echo "==============================================="
    echo " EzBookkeeping Deployment"
    echo "==============================================="
    echo ""

    check_dependencies

    check_local_image

    terraform_apply

    read_outputs

    configure_kubectl

    wait_for_nodes

    verify_cluster

    login_ecr

    push_image

    deploy_kubernetes

    verify_resources

    wait_for_postgres

    wait_for_application

    wait_for_loadbalancer

    deployment_summary

    cleanup

}

main