############################################
# Terraform: Full Infra (Single File)
# - Region: us-east-1
# - VPC, Subnets, IGW, Routes
# - SGs (ALB, Web, RDS)
# - Key Pair (generated)
# - EC2 x2 (public subnets)
# - ALB (HTTP 80)
# - RDS MySQL (private subnets)
# - Auto-generate Ansible artifacts from live TF outputs
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
# Variables (defaults set for your exam)
############################################
variable "region" {
  description = "AWS region where all resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name prefix for tagging AWS resources"
  type        = string
  default     = "streamline"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs for the public subnets across two AZs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for the private subnets across two AZs"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "my_ip_cidr" {
  description = "Your machine's public IP with /32 mask to allow SSH access"
  type        = string
  default     = "3.110.157.51/32"  # <-- your Mumbai IP
}

# App lives inside the same repo under app/v1 and app/v2
variable "app_repo_url" {
  description = "GitHub URL of your application repository containing app/v1 and app/v2"
  type        = string
  default     = "https://github.com/Krish-venom/aws-capstone-exam.git"
}

variable "app_src_version" {
  description = "Which app version to deploy using Ansible (app/v1 or app/v2)"
  type        = string
  default     = "app/v1"
}

variable "db_username" {
  description = "RDS database master username"
  type        = string
  default     = "streamline_admin"
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "employees"
}

############################################
# Providers & Data
############################################
provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Ubuntu 22.04 LTS AMI (Canonical)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter { name = "name"                values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"] }
  filter { name = "virtualization-type" values = ["hvm"] }
}

############################################
# Network: VPC, Subnets, Routes
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
resource "aws_security_group" "alb_sg" {
  name        = "${var.project}-alb-sg"
  description = "ALB security group"
  vpc_id      = aws_vpc.main.id

  ingress { description = "HTTP from Internet" from_port = 80 to_port = 80 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }

  tags = { Name = "${var.project}-alb-sg", Project = var.project }
}

resource "aws_security_group" "web_sg" {
  name        = "${var.project}-web-sg"
  description = "Web servers security group"
  vpc_id      = aws_vpc.main.id

  ingress { description = "HTTP from Internet" from_port = 80 to_port = 80 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  ingress { description = "SSH from my IP"     from_port = 22 to_port = 22 protocol = "tcp" cidr_blocks = [var.my_ip_cidr] }
  egress  { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }

  tags = { Name = "${var.project}-web-sg", Project = var.project }
}

resource "aws_security_group" "rds_sg" {
  name        = "${var.project}-rds-sg"
  description = "RDS security group"
  vpc_id      = aws_vpc.main.id

  egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }

  tags = { Name = "${var.project}-rds-sg", Project = var.project }
}

resource "aws_security_group_rule" "rds_mysql_ingress" {
  type                     = "ingress"
  security_group_id        = aws_security_group.rds_sg.id
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.web_sg.id
  description              = "Allow MySQL from web SG"
}

############################################
# Key Pair (Generate and save locally)
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
  associate_public_ip_address = true
  key_name                    = aws_key_pair.ec2_key.key_name
  vpc_security_group_ids      = [aws_security_group.web_sg.id]

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

  tags = { Name = "${var.project}-alb", Project = var.project }
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
# RDS: MySQL in private subnets
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
# Auto-generate Ansible files from live TF values
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

  ansible_cfg = <<-INI
    [defaults]
    inventory = hosts.ini
    host_key_checking = False
    retry_files_enabled = False
    forks = 10
    timeout = 30
  INI

  site_yml = <<-YML
    ---
    - name: Configure and deploy StreamLine web app (auto-generated)
      hosts: web
      become: yes
      roles:
        - web
  YML

  role_tasks_main = <<-YML
    ---
    - name: Update apt cache
      ansible.builtin.apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Install Apache/PHP/MySQL client/Git
      ansible.builtin.apt:
        name:
          - apache2
          - libapache2-mod-php
          - php
          - php-mysql
          - git
          - mysql-client
        state: present

    - name: Ensure Apache is enabled and running
      ansible.builtin.service:
        name: apache2
        state: started
        enabled: yes

    - name: Ensure document root exists
      ansible.builtin.file:
        path: "{{ document_root }}"
        state: directory
        owner: www-data
        group: www-data
        mode: "0755"

    - name: Checkout application repo
      ansible.builtin.git:
        repo: "{{ app_repo_url }}"
        dest: /opt/app
        version: main
        force: yes

    - name: Deploy selected version to document root
      ansible.builtin.shell: cp -a /opt/app/{{ app_src_version }}/. {{ document_root }}/
      args:
        executable: /bin/bash

    - name: Create db_check.php for RDS connectivity test
      ansible.builtin.template:
        src: "db_check.php.j2"
        dest: "{{ document_root }}/db_check.php"
        mode: "0644"
        owner: www-data
        group: www-data

    - name: Ensure DB exists
      ansible.builtin.shell: >
        mysql -h {{ rds_endpoint }} -u {{ db_user }}
        -p'{{ db_pass }}'
        -e "CREATE DATABASE IF NOT EXISTS {{ db_name }};"
      register: create_db_result
      changed_when: "'ERROR' not in create_db_result.stderr"

    - name: Set ownership for document root
      ansible.builtin.file:
        path: "{{ document_root }}"
        owner: www-data
        group: www-data
        recurse: yes

    - name: Reload Apache
      ansible.builtin.service:
        name: apache2
        state: reloaded
  YML

  db_check_template = <<-PHP
    <?php
    $host = "{{ rds_endpoint }}";
    $user = "{{ db_user }}";
    $pass = "{{ db_pass }}";
    $db   = "{{ db_name }}";

    header('Content-Type: text/plain');

    $mysqli = @new mysqli($host, $user, $pass, $db);

    if ($mysqli->connect_errno) {
      http_response_code(500);
      echo "Database Connection Failed: (" . $mysqli->connect_errno . ") " . $mysqli->connect_error;
      exit;
    }

    echo "Database Connected Successfully";
    $mysqli->close();
  PHP

  deploy_sh = <<-SH
    #!/usr/bin/env bash
    set -euo pipefail
    cd "$(dirname "$0")"
    KEY="../terraform/generated_${var.project}_key.pem"
    echo "Using key: $KEY"
    ansible -i hosts.ini all -m ping -u ubuntu --key-file "$KEY"
    ansible-playbook -i hosts.ini site.yml -u ubuntu --key-file "$KEY"
  SH
}

# Ensure ansible directories exist
resource "null_resource" "prepare_ansible_dirs" {
  provisioner "local-exec" {
    command = <<-CMD
      mkdir -p "${local.ansible_dir}/group_vars" \
               "${local.ansible_dir}/roles/web/tasks" \
               "${local.ansible_dir}/roles/web/templates"
    CMD
  }
}

# Write files
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

resource "local_file" "ansible_cfg" {
  depends_on = [null_resource.prepare_ansible_dirs]
  filename   = "${local.ansible_dir}/ansible.cfg"
  content    = trim(local.ansible_cfg)
  file_permission = "0644"
}

resource "local_file" "site_yml" {
  depends_on = [null_resource.prepare_ansible_dirs]
  filename   = "${local.ansible_dir}/site.yml"
  content    = trim(local.site_yml)
  file_permission = "0644"
}

resource "local_file" "role_tasks_main" {
  depends_on = [null_resource.prepare_ansible_dirs]
  filename   = "${local.ansible_dir}/roles/web/tasks/main.yml"
  content    = trim(local.role_tasks_main)
  file_permission = "0644"
}

resource "local_file" "role_template_dbcheck" {
  depends_on = [null_resource.prepare_ansible_dirs]
  filename   = "${local.ansible_dir}/roles/web/templates/db_check.php.j2"
  content    = trim(local.db_check_template)
  file_permission = "0644"
}

resource "local_file" "deploy_script" {
  depends_on = [null_resource.prepare_ansible_dirs, local_file.ansible_hosts]
  filename   = "${local.ansible_dir}/deploy.sh"
  content    = trim(local.deploy_sh)
  file_permission = "0755"
}

############################################
# Outputs
############################################
output "vpc_id"           { value = aws_vpc.main.id }
output "public_subnets"   { value = [for s in aws_subnet.public : s.id] }
output "private_subnets"  { value = [for s in aws_subnet.private : s.id] }
output "alb_dns_name"     { value = aws_lb.app.dns_name }
output "web_public_ips"   { value = [for i in aws_instance.web : i.public_ip] }
output "rds_endpoint"     { value = aws_db_instance.mysql.address }
output "db_username"      { value = aws_db_instance.mysql.username }
output "db_name"          { value = aws_db_instance.mysql.db_name }

output "db_password" {
  value     = random_password.db_password.result
  sensitive = true
}

# Path to generated SSH private key (use for Ansible/Jenkins)
output "ec2_key_name"     { value = aws_key_pair.ec2_key.key_name }
output "private_key_path" { value = local_file.private_key_pem.filename }
