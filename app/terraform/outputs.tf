output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_arn" {
  description = "VPC ARN"
  value       = aws_vpc.main.arn
}

output "default_route_table_id" {
  description = "Default Route Table"
  value       = aws_vpc.main.default_route_table_id
}

output "default_security_group_id" {
  description = "Default Security Group"
  value       = aws_vpc.main.default_security_group_id
}

output "latest_ami" {

  value = data.aws_ami.amazon_linux.id

}

output "ec2_instance_id" {
  value = aws_instance.app.id
}

output "ec2_public_ip" {
  value = aws_instance.app.public_ip
}

output "ec2_public_dns" {
  value = aws_instance.app.public_dns
}

output "ssh_command" {
  value = "ssh -i keys/${var.project_name}-${var.environment}.pem ec2-user@${aws_instance.app.public_ip}"
}