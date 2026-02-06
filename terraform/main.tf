############################################
# Full Infra (VPC, Subnets, SGs, EC2, ALB, RDS)
# - Region: us-east-1
# - SSH locked to your IP: 3.110.157.51/32
# - Fresh key pair generated and saved locally
# - Ansible inventory/vars auto-generated from live values
############################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

############################################
# Variables (override via terraform.tfvars if you like)
############################################
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project tag/name prefix"
  type        = string
  default     = "streamline"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Two public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Two private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

# Lock SSH to YOUR public IP
variable "my_ip_cidr" {
  description = "Your public IP in CIDR (e.g., 3.110.157.51/32)"
  type        = string
  default     = "3.110.157.51/32"
}

# App repo (your repo with app/v1 and app/v2)
variable "app_repo_url" {
  description = "GitHub URL of the repo that contains app/v1 and app/v2"
  type        = string
  default     = "https://github.com/Krish-venom/aws-capstone-exam.git"
}

# Which app version to deploy via Ansible
variable "app_src_version" {
  description = "app/v1 or app/v2"
  type        = string
  default     = "app/v1"
}

# DB settings
variable "db_username" {
  description = "RDS master user"
  type        = string
  default     = "streamline_admin"
}

variable "db_name" {
  description = "Initial DB name"
  type        = string
  default     = "employees"
}

############################################
# Provider & Data
############################################
provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Ubuntu 22.04 LTS AMI (Canonical) in us-east-1
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter { name = "name"                values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"] }
  filter { name = "virtualization-type" values = ["hvm"] }
}

############################################
# Networking: VPC, Subnets, Routes
############################################
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${var.project}-vpc", Project = var.project }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project}-igw", Project = var.project }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name    = "${var.project}-public-${count.index + 1}"
    Tier    = "public"
    Project = var.project
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name    = "${var.project}-private-${count.index + 1}"
    Tier    = "private"
    Project = var.project
  }
}

# Public route table (0.0.0.0/0 -> IGW)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.project}-public-rt", Project = var.project }
}

resource "aws_route_table_association" "public_assoc" {
  count          = 2
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public[count.index].id
}

# Private route table: no default internet route (RDS only)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project}-private-rt", Project = var.project }
}

resource "aws_route_table_association" "private_assoc" {
  count          = 2
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private[count.index].id
}

############################################
# Security Groups
############################################
# ALB: allow 80 from Internet
resource "aws_security_group" "alb_sg" {
  name        = "${var.project}-alb-sg"
  description = "ALB security group"
  vpc_id      = aws_vpc.main.id

  ingress { description = "HTTP" from_port = 80 to_port = 80 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0   to_port = 0  protocol = "-1"  cidr_blocks = ["0.0.0.0/0"] }

  tags = { Name = "${var.project}-alb-sg", Project = var.project }
}

# Web: HTTP 80 from Internet; SSH 22 from YOUR IP only
resource "aws_security_group" "web_sg" {
  name        = "${var.project}-web-sg"
  description = "Web servers security group"
  vpc_id      = aws_vpc.main.id

  ingress { description = "HTTP" from_port = 80 to_port = 80 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  ingress { description = "SSH"  from_port = 22 to_port = 22 protocol = "tcp" cidr_blocks = [var.my_ip_cidr] }
  egress  { from_port = 0   to_port = 0  protocol = "-1"  cidr_blocks = ["0.0.0.0/0"] }

  tags = { Name = "${var.project}-web-sg", Project = var.project }
}

# RDS: MySQL 3306 only from Web SG
resource "aws_security_group" "rds_sg" {
  name        = "${var.project}-rds-sg"
  description = "RDS security group"
  vpc_id      = aws_vpc.main.id

  egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }

  tags = { Name = "${var.project}-rds-sg", Project = var.project }
}

resource "aws_security_group_rule" "rds_mysql_ingress" {
  type                     = "i" # ingress
  security_group_id        = aws_security_group.rds_sg.id
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.web_sg.id
  description              = "Allow MySQL from web SG"
}

############################################
# Key Pair (generate + save locally)
############################################
resource "tls_private_key" "ec2" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2_key" {
  key_name   = "${var.project}-key"
  public_key = tls_private_key.ec2.public_key_openssh
  tags       = { Name = "${var.project}-key", Project = var.project }
}

resource "local_file" "private_key_pem" {
  filename        = "${path.module}/generated_${var.project}_key.pem"
  content         = tls_private_key.ec2.private_key_pem
  file_permission = "0600"
}

############################################
# EC2 Web Servers (x2) + ALB
############################################
resource "aws_instance" "web" {
  count                       = 2
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public[count.index].id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.ec2_key.key_name

  user_data = <<-EOF
              #!/bin/bash
              export DEBIAN_FRONTEND=noninteractive
              apt-get update -y
              apt-get install -y python3 git
              EOF

  tags = {
    Name    = "${var.project}-web-${count.index + 1}"
    Project = var.project
    Role    = "web"
  }
}

resource "aws_lb" "app" {
  name               = "${var.project}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [for s in aws_subnet.public : s.id]
  tags               = { Name = "${var.project}-alb", Project = var.project }
}

resource "aws_lb_target_group" "web_tg" {
  name     = "${var.project}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = { Project = var.project }
}

resource "aws_lb_target_group_attachment" "attach" {
  count            = 2
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

############################################
# RDS: MySQL (private subnets)
############################################
resource "aws_db_subnet_group" "db_subnets" {
  name       = "${var.project}-db-subnets"
  subnet_ids = [for s in aws_subnet.private : s.id]
  tags       = { Name = "${var.project}-db-subnets", Project = var.project }
}

resource "random_password" "db_password" {
  length  = 16
  special = false
}

resource "aws_db_instance" "mysql" {
  identifier             = "${var.project}-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_subnet_group_name   = aws_db_subnet_group.db_subnets.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  username            = var.db_username
  password            = random_password.db_password.result
  db_name             = var.db_name
  publicly_accessible = false
  multi_az            = false
  storage_encrypted   = true

  skip_final_snapshot = true
  deletion_protection = false

  tags = { Name = "${var.project}-mysql", Project = var.project, Tier = "database" }
}

############################################
# Auto-generate minimal Ansible inputs (inventory + vars)
# (Keeps Terraform and Ansible separate, but inventory comes from TF)
############################################
locals {
  ansible_dir = "${path.module}/../ansible"

  hosts_ini = "[web]\n${join("\n", [for ip in aws_instance.web[*].public_ip : "${ip} ansible_user=ubuntu"])}\n"

  group_vars_all = <<-YAML
    app_repo_url: "${var.app_repo_url}"
    app_src_version: "${var.app_src_version}"
    document_root: "/var/www/html"

    rds_endpoint: "${aws_db_instance.mysql.address}"
    db_user: "${var.db_username}"
    db_pass: "${random_password.db_password.result}"
    db_name: "${var.db_name}"

    alb_dns_name: "${aws_lb.app.dns_name}"
  YAML
}

resource "null_resource" "prepare_ansible_dirs" {
  provisioner "local-exec" {
    command = <<-CMD
      mkdir -p "${local.ansible_dir}/group_vars"
    CMD
  }
}

resource "local_file" "ansible_hosts" {
  depends_on = [null_resource.prepare_ansible_dirs, aws_instance.web]
  filename   = "${local.ansible_dir}/hosts.ini"
  content    = local.hosts_ini
  file_permission = "0644"
}

resource "local_file" "ansible_group_vars" {
  depends_on = [null_resource.prepare_ansible_dirs, aws_db_instance.mysql, aws_lb.app]
  filename   = "${local.ansible_dir}/group_vars/all.yml"
  content    = trim(local.group_vars_all)
  file_permission = "0600"
}

############################################
# Outputs
############################################
output "alb_dns_name"     { value = aws_lb.app.dns_name }
output "web_public_ips"   { value = [for i in aws_instance.web : i.public_ip] }
output "rds_endpoint"     { value = aws_db_instance.mysql.address }
output "db_username"      { value = var.db_username }
output "db_name"          { value = var.db_name }

output "db_password" {
  value     = random_password.db_password.result
  sensitive = true
}

output "ec2_key_name"     { value = aws_key_pair.ec2_key.key_name }
output "private_key_path" { value = local_file.private_key_pem.filename }
output "vpc_id"           { value = aws_vpc.main.id }
