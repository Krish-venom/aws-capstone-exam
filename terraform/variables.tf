variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "streamline"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "my_ip_cidr" {
  description = "Your public IP in CIDR to allow SSH (e.g., 203.0.113.10/32)"
  type        = string
}
