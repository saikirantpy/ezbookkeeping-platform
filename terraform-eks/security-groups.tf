###############################################
# EKS Cluster Security Group
###############################################

resource "aws_security_group" "eks_cluster" {

  name = "${local.project_name}-eks-cluster"

  description = "Security Group for EKS Control Plane"

  vpc_id = aws_vpc.main.id

  tags = merge(

    local.common_tags,

    {
      Name = "${local.project_name}-eks-cluster-sg"
    }

  )

}
###############################################
# Worker Node Security Group
###############################################

resource "aws_security_group" "worker_nodes" {

  name = "${local.project_name}-worker-nodes"

  description = "Security Group for EKS Worker Nodes"

  vpc_id = aws_vpc.main.id

  tags = merge(

    local.common_tags,

    {
      Name = "${local.project_name}-worker-sg"
    }

  )

}
###############################################
# Application Load Balancer
###############################################

resource "aws_security_group" "alb" {

  name = "${local.project_name}-alb"

  description = "Security Group for AWS Load Balancer"

  vpc_id = aws_vpc.main.id

  tags = merge(

    local.common_tags,

    {
      Name = "${local.project_name}-alb-sg"
    }

  )

}