###############################################
# EBS CSI Driver Version
###############################################

data "aws_eks_addon_version" "ebs_csi" {

  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true

}

###############################################
# Pod Identity Agent
###############################################

resource "aws_eks_addon" "pod_identity_agent" {

  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "eks-pod-identity-agent"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.main
  ]
}

###############################################
# EBS CSI IAM Role
###############################################

data "aws_iam_policy_document" "ebs_csi_assume_role" {

  statement {

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]

    principals {

      type = "Service"

      identifiers = [
        "pods.eks.amazonaws.com"
      ]

    }

  }

}

resource "aws_iam_role" "ebs_csi" {

  name = "${local.project_name}-ebs-csi-role"

  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json

  tags = local.common_tags

}

resource "aws_iam_role_policy_attachment" "ebs_csi" {

  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEBSCSIDriverPolicyV2"

}

###############################################
# EBS CSI Driver Addon
###############################################

resource "aws_eks_addon" "ebs_csi" {

  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "aws-ebs-csi-driver"
  addon_version = data.aws_eks_addon_version.ebs_csi.version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  pod_identity_association {

    service_account = "ebs-csi-controller-sa"
    role_arn        = aws_iam_role.ebs_csi.arn

  }

  depends_on = [

    aws_eks_addon.pod_identity_agent,
    aws_iam_role_policy_attachment.ebs_csi

  ]

}