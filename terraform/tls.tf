resource "tls_private_key" "ec2" {

  algorithm = "RSA"

  rsa_bits = 4096

}