#!/bin/bash

set -euo pipefail

############################################################
# EzBookkeeping Destroy Script
############################################################

###############################################
# Configuration
###############################################

PROJECT_NAME="EzBookkeeping"
AWS_REGION="ap-south-1"
TERRAFORM_DIR="./terraform-eks"
K8S_DIR="./eks"

###############################################
# Runtime Flags
###############################################

CLUSTER_EXISTS=false
TF_STATE_EXISTS=false
NAMESPACE_EXISTS=false

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
        ${PROJECT_NAME} Cleanup
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
        jq
    )

    for tool in "${REQUIRED_TOOLS[@]}"
    do
        command -v "$tool" >/dev/null 2>&1 || error "$tool is not installed."
    done

    success "All required tools are installed."

}

###############################################
# AWS Credentials
###############################################

check_aws_credentials() {

    info "Checking AWS credentials..."

    aws sts get-caller-identity >/dev/null

    success "AWS credentials verified."

}

###############################################
# Terraform Directory
###############################################

check_terraform_directory() {

    [[ -d "$TERRAFORM_DIR" ]] || error "Terraform directory not found."

}

###############################################
# Terraform Initialized
###############################################

check_terraform_initialized() {

    [[ -d "$TERRAFORM_DIR/.terraform" ]] || error "Terraform is not initialized."

}

###############################################
# Terraform State
###############################################

check_terraform_state() {

    info "Checking Terraform state..."

    if terraform -chdir="$TERRAFORM_DIR" state list >/dev/null 2>&1 &&
       [[ -n "$(terraform -chdir="$TERRAFORM_DIR" state list 2>/dev/null)" ]]
    then

        TF_STATE_EXISTS=true

        success "Terraform state found."

    else

        warning "Terraform state is empty."

        TF_STATE_EXISTS=false

    fi

}

###############################################
# Terraform Outputs
###############################################

read_outputs() {

    if [[ "$TF_STATE_EXISTS" == false ]]
    then
        return
    fi

    info "Reading Terraform outputs..."

    CLUSTER_NAME=$(terraform -chdir="$TERRAFORM_DIR" output -raw eks_cluster_name)

    VPC_ID=$(terraform -chdir="$TERRAFORM_DIR" output -raw vpc_id)

    success "Terraform outputs loaded."

}

###############################################
# Cluster Detection
###############################################

check_cluster() {

    if [[ "$TF_STATE_EXISTS" == false ]]
    then
        return
    fi

    info "Checking EKS Cluster..."

    if aws eks describe-cluster \
        --region "$AWS_REGION" \
        --name "$CLUSTER_NAME" >/dev/null 2>&1
    then

        CLUSTER_EXISTS=true

        success "Cluster exists."

    else

        warning "Cluster already deleted."

        CLUSTER_EXISTS=false

    fi

}

###############################################
# Configure kubectl
###############################################

configure_kubectl() {

    [[ "$CLUSTER_EXISTS" == false ]] && return

    info "Updating kubeconfig..."

    aws eks update-kubeconfig \
        --region "$AWS_REGION" \
        --name "$CLUSTER_NAME" >/dev/null

    kubectl cluster-info >/dev/null

    success "kubectl configured."

}
############################################################
# Namespace Detection
############################################################

namespace_exists() {

    if [[ "$CLUSTER_EXISTS" == false ]]
    then
        return
    fi

    if kubectl get namespace ezbookkeeping >/dev/null 2>&1
    then
        NAMESPACE_EXISTS=true
        success "Namespace exists."
    else
        NAMESPACE_EXISTS=false
        warning "Namespace already deleted."
    fi

}

############################################################
# Delete Kubernetes Resources
############################################################

delete_kubernetes_resources() {

    [[ "$NAMESPACE_EXISTS" == false ]] && return

    info "Deleting Kubernetes resources..."

    kubectl delete -f "$K8S_DIR/" \
        --ignore-not-found=true \
        --wait=false

    success "Delete request submitted."

}

############################################################
# Wait For Namespace Deletion
############################################################

wait_for_namespace() {

    [[ "$NAMESPACE_EXISTS" == false ]] && return

    info "Waiting for namespace deletion..."

    while kubectl get namespace ezbookkeeping >/dev/null 2>&1
    do
        sleep 5
    done

    success "Namespace deleted."

}

############################################################
# Wait For Classic ELB Deletion
############################################################

wait_for_loadbalancer() {

    info "Checking for remaining Classic Load Balancers..."

    while true
    do

        COUNT=$(
            aws elb describe-load-balancers \
                --region "$AWS_REGION" \
                --query "length(LoadBalancerDescriptions[?VPCId=='${VPC_ID}'])" \
                --output text
        )

        [[ "$COUNT" == "0" ]] && break

        info "Waiting for ELB deletion..."

        sleep 15

    done

    success "No Classic Load Balancers found."

}

############################################################
# Wait For ELB Security Groups
############################################################

wait_for_elb_security_groups() {

    info "Checking for ELB Security Groups..."

    while true
    do

        COUNT=$(
            aws ec2 describe-security-groups \
                --region "$AWS_REGION" \
                --filters Name=vpc-id,Values="$VPC_ID" \
                --query "length(SecurityGroups[?starts_with(GroupName,'k8s-elb-')])" \
                --output text
        )

        [[ "$COUNT" == "0" ]] && break

        info "Waiting for ELB Security Groups to disappear..."

        sleep 10

    done

    success "ELB Security Groups removed."

}

############################################################
# Wait For Network Interfaces
############################################################

wait_for_network_interfaces() {

    info "Checking Network Interfaces..."

    while true
    do

        COUNT=$(
            aws ec2 describe-network-interfaces \
                --region "$AWS_REGION" \
                --filters Name=vpc-id,Values="$VPC_ID" \
                --query "length(NetworkInterfaces)" \
                --output text
        )

        [[ "$COUNT" == "0" ]] && break

        info "Waiting for Network Interfaces to disappear..."

        sleep 10

    done

    success "Network Interfaces removed."

}

############################################################
# Wait Utility
############################################################

wait_until() {

    local DESCRIPTION="$1"
    local COMMAND="$2"
    local TIMEOUT=600
    local INTERVAL=10

    local ELAPSED=0

    info "$DESCRIPTION..."

    while true
    do

        if eval "$COMMAND"
        then
            success "$DESCRIPTION completed."
            return
        fi

        sleep "$INTERVAL"

        ELAPSED=$((ELAPSED+INTERVAL))

        if [[ "$ELAPSED" -ge "$TIMEOUT" ]]
        then
            error "$DESCRIPTION timed out after ${TIMEOUT} seconds."
        fi

    done

}

############################################################
# Terraform Destroy
############################################################

terraform_destroy() {

    info "Destroying Terraform infrastructure..."

    terraform \
        -chdir="$TERRAFORM_DIR" \
        destroy \
        -auto-approve

    success "Terraform destroy completed."

}

############################################################
# Verify Cleanup
############################################################

verify_cleanup() {

    info "Verifying cleanup..."

    if aws eks list-clusters \
        --region "$AWS_REGION" \
        --query "clusters[?@=='$CLUSTER_NAME']" \
        --output text | grep -q "$CLUSTER_NAME"
    then
        error "EKS Cluster still exists."
    fi

    if aws ec2 describe-vpcs \
        --region "$AWS_REGION" \
        --filters Name=vpc-id,Values="$VPC_ID" \
        --query "Vpcs" \
        --output text | grep -q "$VPC_ID"
    then
        error "VPC still exists."
    fi

    success "AWS cleanup verified."

}

############################################################
# Summary
############################################################

summary() {

    echo
    echo "========================================="
    echo
    echo "Cleanup Completed Successfully"
    echo
    echo "Cluster : ${CLUSTER_NAME}"
    echo "VPC     : ${VPC_ID}"
    echo
    echo "========================================="
    echo

}

############################################################
# Main
############################################################

main() {

    START_TIME=$(date +%s)

    banner

    check_dependencies

    check_aws_credentials

    check_terraform_directory

    check_terraform_initialized

    check_terraform_state

    if [[ "$TF_STATE_EXISTS" == false ]]
    then
        success "Nothing to destroy."
        exit 0
    fi

    read_outputs

    check_cluster

    configure_kubectl

    namespace_exists

    delete_kubernetes_resources

    wait_for_namespace

    wait_for_loadbalancer

    wait_for_elb_security_groups

    terraform_destroy

    wait_for_network_interfaces

    verify_cleanup

    END_TIME=$(date +%s)

    summary

    echo "Duration : $((END_TIME-START_TIME)) seconds"

}

main "$@"
