resource "tls_private_key" "ec2" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2_key" {
  key_name   = "${var.project}-key"
  public_key = tls_private_key.ec2.public_key_openssh
  tags       = { Name = "${var.project}-key", Project = var.project }
}

# Save the private key to a local file (NEVER COMMIT THIS FILE)
resource "local_file" "private_key_pem" {
  filename = "${path.module}/generated_${var.project}_key.pem"
  content  = tls_private_key.ec2.private_key_pem
  file_permission = "0600"
}
``
