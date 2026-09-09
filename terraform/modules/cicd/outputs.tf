output "gitlab_connection_arn" {
  value = aws_codestarconnections_connection.gitlab.arn
}

output "pipeline_names" {
  value = aws_codepipeline.terraform.name
}