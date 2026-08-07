###############################################
# EKS Cluster Assume Role Policy
###############################################

data "aws_iam_policy_document" "eks_assume_role" {

  statement {

    actions = ["sts:AssumeRole"]

    principals {

      type = "Service"

      identifiers = ["eks.amazonaws.com"]

    }

  }

}
###############################################
# EKS Cluster IAM Role
###############################################

resource "aws_iam_role" "eks_cluster" {

  name = "${local.project_name}-eks-cluster-role"

  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json

  tags = local.common_tags

}
###############################################
# Amazon EKS Cluster Policy
###############################################

resource "aws_iam_role_policy_attachment" "eks_cluster" {

  role = aws_iam_role.eks_cluster.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"

}
###############################################
# Worker Node Assume Role
###############################################

data "aws_iam_policy_document" "worker_assume_role" {

  statement {

    actions = ["sts:AssumeRole"]

    principals {

      type = "Service"

      identifiers = ["ec2.amazonaws.com"]

    }

  }

}
###############################################
# Worker Node IAM Role
###############################################

resource "aws_iam_role" "worker_nodes" {

  name = "${local.project_name}-worker-role"

  assume_role_policy = data.aws_iam_policy_document.worker_assume_role.json

  tags = local.common_tags

}
resource "aws_iam_role_policy_attachment" "worker_policy" {

  role = aws_iam_role.worker_nodes.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"

}
resource "aws_iam_role_policy_attachment" "ecr_policy" {

  role = aws_iam_role.worker_nodes.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"

}
resource "aws_iam_role_policy_attachment" "cni_policy" {

  role = aws_iam_role.worker_nodes.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"

}