resource "aws_security_group" "efs_sg" {
  name        = "efs-sg"
  description = "Allow NFS from lambda security group"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [var.lambda_security_group_id]
    description     = "Allow NFS from lambda"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_efs_file_system" "this" {
  creation_token = "efs-${random_id.rnd.hex}"
  encrypted      = true
  tags           = { Name = "efs-${var.name}" }
}

resource "random_id" "rnd" {
  byte_length = 4
}

resource "aws_efs_access_point" "this" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/lambda"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "0755"
    }
  }
}

resource "aws_efs_mount_target" "mt" {
  for_each        = { for id in var.subnet_ids : id => id }
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.key
  security_groups = [aws_security_group.efs_sg.id]
}

output "efs_file_system_id" {
  value = aws_efs_file_system.this.id
}

output "efs_file_system_arn" {
  value = aws_efs_file_system.this.arn
}

output "efs_access_point_id" {
  value = aws_efs_access_point.this.id
}

output "efs_access_point_arn" {
  value = aws_efs_access_point.this.arn
}
