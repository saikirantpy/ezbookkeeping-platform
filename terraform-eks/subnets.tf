###############################################
# Public Subnet 1
###############################################

resource "aws_subnet" "public_1" {

  vpc_id = aws_vpc.main.id

  cidr_block = var.public_subnet_cidrs[0]

  availability_zone = var.availability_zones[0]

  map_public_ip_on_launch = true

  tags = merge(

    local.common_tags,

    {
      Name = "${local.project_name}-public-1"

      "kubernetes.io/role/elb"                    = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }

  )

}
###############################################
# Public Subnet 2
###############################################

resource "aws_subnet" "public_2" {

  vpc_id = aws_vpc.main.id

  cidr_block = var.public_subnet_cidrs[1]

  availability_zone = var.availability_zones[1]

  map_public_ip_on_launch = true

  tags = merge(

    local.common_tags,

    {
      Name = "${local.project_name}-public-2"

      "kubernetes.io/role/elb"                    = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }

  )

}
###############################################
# Private Subnet 1
###############################################

resource "aws_subnet" "private_1" {

  vpc_id = aws_vpc.main.id

  cidr_block = var.private_subnet_cidrs[0]

  availability_zone = var.availability_zones[0]

  map_public_ip_on_launch = false

  tags = merge(

    local.common_tags,

    {
      Name = "${local.project_name}-private-1"

      "kubernetes.io/role/internal-elb"           = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }

  )

}
###############################################
# Private Subnet 2
###############################################

resource "aws_subnet" "private_2" {

  vpc_id = aws_vpc.main.id

  cidr_block = var.private_subnet_cidrs[1]

  availability_zone = var.availability_zones[1]

  map_public_ip_on_launch = false

  tags = merge(

    local.common_tags,

    {
      Name = "${local.project_name}-private-2"

      "kubernetes.io/role/internal-elb"           = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }

  )

}