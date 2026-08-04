############################################
# Latest Amazon Linux AMI
############################################

data "aws_ami" "amazon_linux" {

  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

############################################
# EC2 Instance
############################################

resource "aws_instance" "app" {

  ami = data.aws_ami.amazon_linux.id

  instance_type = var.instance_type

  subnet_id = aws_subnet.public.id

  vpc_security_group_ids = [
    aws_security_group.app.id
  ]

  key_name = aws_key_pair.main.key_name

  associate_public_ip_address = true

  monitoring = true

  user_data                   = templatefile(
  "${path.module}/scripts/bootstrap.sh.tpl",
  {
    github_repository = var.github_repository
    github_branch     = var.github_branch
  }
  )
  user_data_replace_on_change = true

  metadata_options {

    http_endpoint = "enabled"

    http_tokens = "required"

  }

  disable_api_termination = false

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name        = "${var.project_name}-ec2"
    Environment = var.environment
  }
}