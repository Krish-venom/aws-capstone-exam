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
  username               = "streamline_admin"
  password               = random_password.db_password.result
  db_name                = "employees"
  multi_az               = false
  publicly_accessible    = false
  storage_encrypted      = true
  skip_final_snapshot    = true
  deletion_protection    = false

  tags = { Name = "${var.project}-mysql", Project = var.project, Tier = "database" }
}
