# ALB SG: allow HTTP 80 from Internet
resource "aws_security_group" "alb_sg" {
  name        = "${var.project}-alb-sg"
  description = "ALB SG"
  vpc_id      = aws_vpc.main.id

  ingress { from_port = 80 to_port = 80 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0  to_port = 0  protocol = "-1"  cidr_blocks = ["0.0.0.0/0"] }

  tags = { Name = "${var.project}-alb-sg", Project = var.project }
}

# Web SG: HTTP from Internet; SSH from your IP
resource "aws_security_group" "web_sg" {
  name        = "${var.project}-web-sg"
  description = "Web SG"
  vpc_id      = aws_vpc.main.id

  ingress { from_port = 80 to_port = 80 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  ingress { from_port = 22 to_port = 22 protocol = "tcp" cidr_blocks = [var.my_ip_cidr] }
  egress  { from_port = 0  to_port = 0  protocol = "-1"  cidr_blocks = ["0.0.0.0/0"] }

  tags = { Name = "${var.project}-web-sg", Project = var.project }
}

# RDS SG: allow MySQL only from Web SG
resource "aws_security_group" "rds_sg" {
  name        = "${var.project}-rds-sg"
  description = "RDS SG"
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
