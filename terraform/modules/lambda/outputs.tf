output "lambda_function_name" {
  description = "example lambda name"
  sensitive   = false
  value       = aws_lambda_function.example.function_name
}

output "lambda_function" {
  value = aws_lambda_function.example
}

output "gdal_layer_arn" {
  description = "GDAL Lambda layer ARN"
  value       = aws_lambda_layer_version.gdal.arn
}