resource "local_file" "private_key" {

  filename = "${path.module}/keys/${var.project_name}-${var.environment}.pem"

  content = tls_private_key.ec2.private_key_pem

  file_permission = "0400"

}

resource "aws_key_pair" "main" {

  key_name = "${var.project_name}-${var.environment}"

  public_key = tls_private_key.ec2.public_key_openssh

}