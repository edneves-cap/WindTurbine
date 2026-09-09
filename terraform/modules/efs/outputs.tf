output "efs_file_system_id" {
  value = aws_efs_file_system.this.id
}

output "efs_access_point_arn" {
  value = aws_efs_access_point.this.arn
}
