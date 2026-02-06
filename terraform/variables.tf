############################################
# Global Variables
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

############################################
# Network Variables
############################################

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs for the public subnets across two AZs"
  type        = list(string)
  default     = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for the private subnets across two AZs"
  type        = list(string)
  default     = [
    "10.0.3.0/24",
    "10.0.4.0/24"
  ]
}

############################################
# Access Control
############################################

variable "my_ip_cidr" {
  description = "Your machine's public IP with /32 mask to allow SSH access"
  type        = string
}

############################################
# Application Variables
############################################

variable "app_repo_url" {
  description = "GitHub URL of your application repository containing app/v1 and app/v2"
  type        = string
}

variable "app_src_version" {
  description = "Which app version to deploy using Ansible (app/v1 or app/v2)"
  type        = string
  default     = "app/v1"
}

############################################
# DB Variables (Optional override)
############################################

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
