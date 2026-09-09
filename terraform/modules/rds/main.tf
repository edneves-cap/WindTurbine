resource "aws_db_subnet_group" "this" {
  name       = "rds-subnet-group-${random_id.rnd.hex}"
  subnet_ids = var.subnet_ids
  tags = {
    Name = "rds-subnet-group"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow Postgres access (dev)"
  vpc_id      = var.vpc_id

  ingress {
    description = "Postgres"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "random_id" "rnd" {
  byte_length = 4
}

resource "random_password" "db" {
  length = 16
  #override_characters = "@#%&*!"
}

resource "aws_db_instance" "postgres" {
  identifier             = "dev-postgres-db"
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "15.19"
  instance_class         = var.instance_class
  db_name                = var.db_name
  username               = var.db_username
  password               = random_password.db.result
  skip_final_snapshot    = true
  publicly_accessible    = true # true to verify without complex connection
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.this.name
  tags = {
    Environment = "dev"
  }
}

resource "aws_secretsmanager_secret" "db_secret" {
  name = "rds-db-secret"
}

resource "aws_secretsmanager_secret_version" "db_secret_ver" {
  secret_id = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    username = aws_db_instance.postgres.username,
    password = random_password.db.result,
    host     = aws_db_instance.postgres.address,
    port     = aws_db_instance.postgres.port,
    dbname   = var.db_name
  })
}

output "rds_address" {
  value = aws_db_instance.postgres.address
}

output "rds_username" {
  value = aws_db_instance.postgres.username
}

output "rds_password" {
  value     = random_password.db.result
  sensitive = true
}

output "aws_security_group_id" {
  value = aws_security_group.rds_sg.id
}

output "aws_db_subnet_group_id" {
  value = aws_db_subnet_group.this.subnet_ids
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db_secret.arn
}

output "db_name" {
  value = var.db_name
}

output "db_username" {
  value = aws_db_instance.postgres.username
}
