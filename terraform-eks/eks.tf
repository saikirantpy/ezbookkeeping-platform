###############################################
# Amazon EKS Cluster
###############################################

resource "aws_eks_cluster" "main" {

  name = var.cluster_name

  role_arn = aws_iam_role.eks_cluster.arn

  version = "1.33"

  vpc_config {

    subnet_ids = [

      aws_subnet.public_1.id,
      aws_subnet.public_2.id

    ]

    security_group_ids = [

      aws_security_group.eks_cluster.id

    ]

    endpoint_private_access = false

    endpoint_public_access = true

  }

  depends_on = [

    aws_iam_role_policy_attachment.eks_cluster

  ]

  tags = merge(

    local.common_tags,

    {

      Name = var.cluster_name

    }

  )

}