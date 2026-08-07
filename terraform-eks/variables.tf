###############################################
# Project Information
###############################################

variable "project_name" {

  description = "Project Name"

  type = string

}

variable "environment" {

  description = "Deployment Environment"

  type = string

}

###############################################
# AWS Configuration
###############################################

variable "aws_region" {

  description = "AWS Region"

  type = string

}

###############################################
# Networking
###############################################

variable "vpc_cidr" {

  description = "VPC CIDR Block"

  type = string

}

variable "availability_zones" {

  description = "Availability Zones"

  type = list(string)

}

variable "public_subnet_cidrs" {

  description = "Public Subnet CIDRs"

  type = list(string)

}

variable "private_subnet_cidrs" {

  description = "Private Subnet CIDRs"

  type = list(string)

}

###############################################
# Amazon EKS
###############################################

variable "cluster_name" {

  description = "Amazon EKS Cluster Name"

  type = string

}

variable "node_group_name" {

  description = "EKS Managed Node Group"

  type = string

}

variable "kubernetes_version" {

  description = "Amazon EKS Kubernetes Version"

  type = string

}

variable "instance_type" {
  description = "EKS Worker Node Instance Type"
  type        = string
}