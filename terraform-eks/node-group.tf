###############################################
# EKS Managed Node Group
###############################################

resource "aws_eks_node_group" "main" {

  cluster_name = aws_eks_cluster.main.name

  node_group_name = var.node_group_name

  node_role_arn = aws_iam_role.worker_nodes.arn

  subnet_ids = [

    aws_subnet.public_1.id,
    aws_subnet.public_2.id

  ]

  capacity_type = "ON_DEMAND"

  ami_type = "AL2023_x86_64_STANDARD"

  instance_types = [

    "t3.small"

  ]

  disk_size = 20

  scaling_config {

    desired_size = 2

    min_size = 1

    max_size = 2

  }

  update_config {

    max_unavailable = 1

  }

  depends_on = [

    aws_iam_role_policy_attachment.worker_policy,

    aws_iam_role_policy_attachment.ecr_policy,

    aws_iam_role_policy_attachment.cni_policy

  ]

  tags = merge(

    local.common_tags,

    {

      Name = "${local.project_name}-node-group"

    }

  )

}