###############################################
# EKS Control Plane Security Group
###############################################

resource "aws_security_group" "control_plane" {

  name        = "${local.project_name}-control-plane"
  description = "Security Group for Amazon EKS Control Plane"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-control-plane-sg"
    }
  )

}

###############################################
# Control Plane Outbound
###############################################

resource "aws_vpc_security_group_egress_rule" "control_plane_outbound" {

  security_group_id = aws_security_group.control_plane.id

  cidr_ipv4 = "0.0.0.0/0"

  ip_protocol = "-1"

}

###############################################
# Application Load Balancer Security Group
###############################################

resource "aws_security_group" "alb" {

  name        = "${local.project_name}-alb"
  description = "Security Group for AWS Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-alb-sg"
    }
  )

}

###############################################
# ALB HTTP Inbound
###############################################

resource "aws_vpc_security_group_ingress_rule" "alb_http" {

  security_group_id = aws_security_group.alb.id

  cidr_ipv4 = "0.0.0.0/0"

  from_port = 80
  to_port   = 80

  ip_protocol = "tcp"

}

###############################################
# ALB HTTPS Inbound
###############################################

resource "aws_vpc_security_group_ingress_rule" "alb_https" {

  security_group_id = aws_security_group.alb.id

  cidr_ipv4 = "0.0.0.0/0"

  from_port = 443
  to_port   = 443

  ip_protocol = "tcp"

}

###############################################
# ALB Outbound
###############################################

resource "aws_vpc_security_group_egress_rule" "alb_outbound" {

  security_group_id = aws_security_group.alb.id

  cidr_ipv4 = "0.0.0.0/0"

  ip_protocol = "-1"

}