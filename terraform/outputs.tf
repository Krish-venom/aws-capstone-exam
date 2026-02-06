output "vpc_id"            { value = aws_vpc.main.id }
output "public_subnets"    { value = [for s in aws_subnet.public : s.id] }
output "private_subnets"   { value = [for s in aws_subnet.private : s.id] }
output "alb_dns_name"      { value = aws_lb.app.dns_name }
output "web_public_ips"    { value = [for i in aws_instance.web : i.public_ip] }
output "rds_endpoint"      { value = aws_db_instance.mysql.address }
output "db_username"       { value = aws_db_instance.mysql.username }
output "db_name"           { value = aws_db_instance.mysql.db_name }
output "db_password" {
  value     = random_password.db_password.result
  sensitive = true
}

# Key pair outputs
output "ec2_key_name"      { value = aws_key_pair.ec2_key.key_name }
output "private_key_path"  { value = local_file.private_key_pem.filename }
