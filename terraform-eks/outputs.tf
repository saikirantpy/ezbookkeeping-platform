###############################################
# VPC ID
###############################################

output "vpc_id" {

  description = "VPC ID"

  value = aws_vpc.main.id

}

###############################################
# Public Subnets
###############################################

output "public_subnet_ids" {

  description = "Public Subnet IDs"

  value = [

    aws_subnet.public_1.id,
    aws_subnet.public_2.id

  ]

}

###############################################
# Private Subnets
###############################################

output "private_subnet_ids" {

  description = "Private Subnet IDs"

  value = [

    aws_subnet.private_1.id,
    aws_subnet.private_2.id

  ]

}

###############################################
# ECR Repository
###############################################

output "ecr_repository_url" {

  description = "Amazon ECR Repository"

  value = aws_ecr_repository.main.repository_url

}

###############################################
# EKS Cluster Name
###############################################

output "eks_cluster_name" {

  description = "Amazon EKS Cluster Name"

  value = aws_eks_cluster.main.name

}

###############################################
# EKS Endpoint
###############################################

output "eks_cluster_endpoint" {

  description = "EKS API Server Endpoint"

  value = aws_eks_cluster.main.endpoint

}

###############################################
# EKS Certificate
###############################################

output "eks_cluster_certificate" {

  description = "EKS Certificate"

  value = aws_eks_cluster.main.certificate_authority[0].data

  sensitive = true

}
###############################################
# Node Group
###############################################

output "node_group_name" {

  description = "Managed Node Group"

  value = aws_eks_node_group.main.node_group_name

}