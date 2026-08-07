###############################################
# Public Route Table
###############################################

resource "aws_route_table" "public" {

  vpc_id = aws_vpc.main.id

  tags = merge(

    local.common_tags,

    {
      Name = "${local.project_name}-public-rt"
    }

  )

}
###############################################
# Internet Route
###############################################

resource "aws_route" "public_internet" {

  route_table_id = aws_route_table.public.id

  destination_cidr_block = "0.0.0.0/0"

  gateway_id = aws_internet_gateway.main.id

}
resource "aws_route_table_association" "public_1" {

  subnet_id = aws_subnet.public_1.id

  route_table_id = aws_route_table.public.id

}
resource "aws_route_table_association" "public_2" {

  subnet_id = aws_subnet.public_2.id

  route_table_id = aws_route_table.public.id

}
###############################################
# Private Route Table
###############################################

resource "aws_route_table" "private" {

  vpc_id = aws_vpc.main.id

  tags = merge(

    local.common_tags,

    {
      Name = "${local.project_name}-private-rt"
    }

  )

}
resource "aws_route_table_association" "private_1" {

  subnet_id = aws_subnet.private_1.id

  route_table_id = aws_route_table.private.id

}
resource "aws_route_table_association" "private_2" {

  subnet_id = aws_subnet.private_2.id

  route_table_id = aws_route_table.private.id

}