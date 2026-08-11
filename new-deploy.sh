#!/bin/bash

set -euo pipefail

############################################################
# EzBookkeeping Deployment Script
############################################################

###############################################
# Configuration
###############################################

PROJECT_NAME="EzBookkeeping"

AWS_REGION="ap-south-1"

TERRAFORM_DIR="./terraform-eks"

K8S_DIR="./eks"

IMAGE_REPOSITORY="306404/ezbookkeeping-platform"

###############################################
# Colors
###############################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

    exit 1

}

###############################################
# Banner
###############################################

banner() {

cat <<EOF

===============================================
        ${PROJECT_NAME} Deployment
===============================================

EOF

}

###############################################
# Dependency Check
###############################################

check_dependencies() {

    info "Checking required tools..."

    REQUIRED_TOOLS=(
        terraform
        kubectl
        aws
        docker
        jq
    )

    for tool in "${REQUIRED_TOOLS[@]}"
    do

        if ! command -v "$tool" >/dev/null 2>&1
        then
            error "$tool is not installed."
        fi

    done

    success "All required tools are installed."

}
############################################################
# Check AWS Credentials
############################################################

check_aws_credentials() {

    info "Checking AWS credentials..."

    aws sts get-caller-identity >/dev/null

    success "AWS credentials verified."

}
############################################################
# Check Docker
############################################################

check_docker() {

    info "Checking Docker daemon..."

    docker info >/dev/null

    success "Docker daemon is running."

}

###############################################
# Terraform Init
###############################################

terraform_init() {

    info "Initializing Terraform..."

    terraform -chdir="$TERRAFORM_DIR" init

    success "Terraform initialized."

}

###############################################
# Terraform Apply
###############################################

terraform_apply() {

    info "Applying Terraform Infrastructure..."

    terraform \
        -chdir="$TERRAFORM_DIR" \
        apply \
        -auto-approve

    success "Infrastructure created."

}

###############################################
# Read Terraform Outputs
###############################################

read_outputs() {

    info "Reading Terraform Outputs..."

    ECR_REPOSITORY=$(
        terraform \
        -chdir="$TERRAFORM_DIR" \
        output -raw ecr_repository_url
    )

    CLUSTER_NAME=$(
        terraform \
        -chdir="$TERRAFORM_DIR" \
        output -raw eks_cluster_name
    )

    success "Terraform outputs loaded."

}

###############################################
# Configure kubectl
###############################################

configure_kubectl() {

    info "Configuring kubectl..."

    aws eks update-kubeconfig \
        --region "$AWS_REGION" \
        --name "$CLUSTER_NAME" >/dev/null

    kubectl cluster-info >/dev/null

    success "kubectl configured."

}

###############################################
# Wait For Cluster
###############################################

wait_for_cluster() {

    info "Waiting for EKS Nodes..."

    kubectl wait \
        --for=condition=Ready \
        nodes \
        --all \
        --timeout=15m

    success "All nodes are Ready."

}

############################################################
# Find Latest AMD64 Image
############################################################

find_amd64_image() {

    info "Searching for latest AMD64 image in ${IMAGE_REPOSITORY}..."

    LOCAL_IMAGE=""

    info "Available images:"

    docker images "$IMAGE_REPOSITORY"

    while read -r IMAGE
    do

        [[ -z "$IMAGE" ]] && continue

        ARCH=$(docker image inspect "$IMAGE" \
            --format '{{.Architecture}}' 2>/dev/null)

        if [[ "$ARCH" == "amd64" ]]
        then
            LOCAL_IMAGE="$IMAGE"
            break
        fi

    done < <(
        docker images "$IMAGE_REPOSITORY" \
            --format "{{.Repository}}:{{.Tag}}"
    )

    if [[ -z "$LOCAL_IMAGE" ]]
    then
        error "No compatible AMD64 image found in ${IMAGE_REPOSITORY}"
    fi

    success "Selected image: $LOCAL_IMAGE"

}

############################################################
# Login to Amazon ECR
############################################################

login_ecr() {

    info "Logging into Amazon ECR..."

    aws ecr get-login-password \
        --region "$AWS_REGION" | \
        docker login \
        --username AWS \
        --password-stdin \
        "$(echo "$ECR_REPOSITORY" | cut -d'/' -f1)"

    success "Logged into ECR."

}

############################################################
# Tag Image
############################################################

tag_image() {

    info "Tagging image..."

    docker tag \
        "$LOCAL_IMAGE" \
        "${ECR_REPOSITORY}:latest"

    success "Image tagged."

}

############################################################
# Push Image
############################################################

push_image() {

    info "Pushing image to Amazon ECR..."

    docker push "${ECR_REPOSITORY}:latest"

    success "Image pushed successfully."

}

############################################################
# Prepare Kubernetes YAML
############################################################

prepare_manifests() {

    info "Preparing Kubernetes manifests..."

    TEMP_DIR=$(mktemp -d)

    cp -R "$K8S_DIR/"* "$TEMP_DIR/"

    find "$TEMP_DIR" -type f -name "*.yaml" \
        -exec sed -i.bak \
        "s|__ECR_REPOSITORY__|${ECR_REPOSITORY}|g" {} \;

    find "$TEMP_DIR" -name "*.bak" -delete

    success "Manifests prepared."

}

############################################################
# Deploy Kubernetes Resources
############################################################

deploy_kubernetes() {

    info "Deploying Kubernetes resources..."

    #########################################
    # Namespace
    #########################################

    kubectl apply -f "$TEMP_DIR/namespace.yaml"

    until kubectl get namespace ezbookkeeping >/dev/null 2>&1
    do
        sleep 2
    done

    #########################################
    # Secret & ConfigMap
    #########################################

    kubectl apply -f "$TEMP_DIR/secret.yaml"

    kubectl apply -f "$TEMP_DIR/configmap.yaml"

    #########################################
    # Persistent Volumes
    #########################################

    kubectl apply -f "$TEMP_DIR/postgres-pvc.yaml"

    kubectl apply -f "$TEMP_DIR/app-pvc.yaml"

    #########################################
    # PostgreSQL
    #########################################

    kubectl apply -f "$TEMP_DIR/postgres-deployment.yaml"

    kubectl apply -f "$TEMP_DIR/postgres-service.yaml"

    #########################################
    # Wait PostgreSQL
    #########################################

    info "Waiting for PostgreSQL..."

    kubectl rollout status \
        deployment/postgres \
        -n ezbookkeeping \
        --timeout=10m

    success "PostgreSQL is Ready."

    #########################################
    # EzBookkeeping
    #########################################

    kubectl apply -f "$TEMP_DIR/ezbookkeeping-deployment.yaml"

    kubectl apply -f "$TEMP_DIR/ezbookkeeping-service.yaml"

    #########################################
    # HPA
    #########################################

    if [[ -f "$TEMP_DIR/hpa.yaml" ]]
    then
        kubectl apply -f "$TEMP_DIR/hpa.yaml"
    fi

    success "Kubernetes resources deployed."

}

############################################################
# Wait For Application
############################################################

wait_for_application() {

    info "Waiting for EzBookkeeping..."

    kubectl rollout status \
        deployment/ezbookkeeping \
        -n ezbookkeeping \
        --timeout=10m

    success "Application is Ready."

}

############################################################
# Wait For LoadBalancer
############################################################

wait_for_loadbalancer() {

    info "Waiting for LoadBalancer..."

    while true
    do

        HOSTNAME=$(kubectl get svc ezbookkeeping \
            -n ezbookkeeping \
            -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

        IP=$(kubectl get svc ezbookkeeping \
            -n ezbookkeeping \
            -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

        if [[ -n "$HOSTNAME" ]]
        then
            EXTERNAL_ENDPOINT="$HOSTNAME"
            break
        fi

        if [[ -n "$IP" ]]
        then
            EXTERNAL_ENDPOINT="$IP"
            break
        fi

        sleep 10

    done

    success "LoadBalancer Ready."

}

############################################################
# Print Application URL
############################################################

print_application_url() {

    echo
    echo "==========================================="
    echo "Deployment Successful"
    echo "==========================================="
    echo
    echo "Application URL:"
    echo
    echo "http://${EXTERNAL_ENDPOINT}:8080"
    echo

}

############################################################
# Cleanup
############################################################

cleanup() {

    if [[ -n "${TEMP_DIR:-}" && -d "${TEMP_DIR}" ]]
    then
        rm -rf "${TEMP_DIR}"
    fi

}

############################################################
# Error Handler
############################################################

failure() {

    echo
    error "Deployment Failed."

    echo
    echo "========== Cluster =========="
    kubectl get nodes || true

    echo
    echo "========== Pods =========="
    kubectl get pods -A || true

    echo
    echo "========== Describe EzBookkeeping =========="
    kubectl describe deployment ezbookkeeping -n ezbookkeeping || true

    echo
    echo "========== Recent Events =========="
    kubectl get events -A --sort-by=.lastTimestamp | tail -30 || true

    echo
    echo "========== PVC =========="
    kubectl get pvc -A || true

    echo
    echo "========== Services =========="
    kubectl get svc -A || true

    cleanup

    exit 1

}

trap failure ERR

############################################################
# Optional Build
############################################################

build_image() {

    login_ecr

    info "Building Multi-Architecture Image..."

    docker buildx build \
        --platform linux/amd64,linux/arm64 \
        -t "${ECR_REPOSITORY}:latest" \
        --push \
        .

    success "Multi-Architecture image built."

}

############################################################
# Parse Arguments
############################################################

BUILD_IMAGE=false

if [[ $# -gt 0 ]]
then

    case "$1" in

        --build)

            BUILD_IMAGE=true

            ;;

    esac

fi

############################################################
# Main
############################################################

main() {

    START_TIME=$(date +%s)

    banner

    check_dependencies

    check_aws_credentials

    check_docker

    terraform_init

    terraform_apply

    read_outputs

    configure_kubectl

    wait_for_cluster

    if [[ "$BUILD_IMAGE" == true ]]
    then

        build_image

    else

        find_amd64_image

        login_ecr

        tag_image

        push_image

    fi

    prepare_manifests

    deploy_kubernetes

    wait_for_application

    wait_for_loadbalancer

    END_TIME=$(date +%s)

    ELAPSED=$((END_TIME-START_TIME))

    print_application_url

    echo "========================================="
    echo
    echo "Deployment Summary"
    echo
    echo "Cluster      : ${CLUSTER_NAME}"
    echo "Repository   : ${ECR_REPOSITORY}"

    if [[ "$BUILD_IMAGE" == true ]]
    then
        echo "Image        : Multi-Arch Build"
    else
        echo "Image        : ${LOCAL_IMAGE}"
    fi

    echo "Duration     : ${ELAPSED} Seconds"
    echo
    echo "========================================="

    cleanup

}

main "$@"