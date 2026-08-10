###############################################
# EBS CSI Driver IAM Assume Role Policy
###############################################

data "aws_iam_policy_document" "ebs_csi_assume_role" {

  statement {

    actions = ["sts:AssumeRole"]

    principals {

      type = "Service"

      identifiers = ["pods.eks.amazonaws.com"]

    }

  }

}

###############################################
# EBS CSI Driver IAM Role
###############################################

resource "aws_iam_role" "ebs_csi" {

  name = "${local.project_name}-ebs-csi-role"

  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json

  tags = local.common_tags

}

###############################################
# Attach AWS Managed Policy
###############################################

resource "aws_iam_role_policy_attachment" "ebs_csi" {

  role = aws_iam_role.ebs_csi.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"

}

###############################################
# EKS Pod Identity Association
###############################################

resource "aws_eks_pod_identity_association" "ebs_csi" {

  cluster_name    = aws_eks_cluster.main.name

  namespace       = "kube-system"

  service_account = "ebs-csi-controller-sa"

  role_arn = aws_iam_role.ebs_csi.arn

}

###############################################
# Amazon EBS CSI Driver Addon
###############################################

resource "aws_eks_addon" "ebs_csi" {

  cluster_name = aws_eks_cluster.main.name

  addon_name = "aws-ebs-csi-driver"

  service_account_role_arn = aws_iam_role.ebs_csi.arn

  resolve_conflicts_on_create = "OVERWRITE"

  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [

    aws_eks_node_group.main,
    aws_eks_pod_identity_association.ebs_csi

  ]

}