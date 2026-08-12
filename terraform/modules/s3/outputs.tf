output "aws_s3_bucket_name" {
  description = "AWS S3 main bucket name"
  value       = var.bucket_name
  sensitive   = false
}
