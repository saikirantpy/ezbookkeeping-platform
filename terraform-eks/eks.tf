###############################################
# Amazon EKS Cluster
###############################################

resource "aws_eks_cluster" "main" {

  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn

  version = var.kubernetes_version

  enabled_cluster_log_types = [

    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"

  ]

  vpc_config {

    subnet_ids = [

      aws_subnet.public_1.id,
      aws_subnet.public_2.id,
      aws_subnet.private_1.id,
      aws_subnet.private_2.id

    ]

    security_group_ids = [

      aws_security_group.control_plane.id

    ]

    endpoint_private_access = false

    endpoint_public_access = true

  }

  depends_on = [

    aws_iam_role_policy_attachment.eks_cluster,
    aws_internet_gateway.main

  ]

  tags = merge(

    local.common_tags,

    {

      Name = var.cluster_name

    }

  )

}