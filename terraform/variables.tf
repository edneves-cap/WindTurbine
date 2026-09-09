variable "data_directory" {
  description = "Directory containing CSV data files to upload"
  type        = string
  default     = "raw"
}

variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "eu-north-1"
}


variable "db_password" {
  description = "RDS root user password"
  type        = string
  sensitive   = true
  default     = "hashicorp"
}

variable "environment" {
  description = "Deployment environment (dev/test/prod)"
  type        = string
  default     = "dev"
}

variable "app_version" {
  description = "Application version or source commit used by CI/CD"
  type        = string
  default     = "local"
}

variable "bucket_name" {
  description = "S3 bucket name for data"
  type        = string
  default     = "windmill-pred-data"
}

variable "enable_cicd" {
  description = "Create the GitLab-connected CodePipeline and CodeBuild deployment infrastructure"
  type        = bool
  default     = false
}

variable "gitlab_repository" {
  description = "GitLab repository in namespace/project format"
  type        = string
  default     = ""
}

variable "cicd_artifact_bucket_name" {
  description = "Globally unique S3 bucket name for CodePipeline artifacts"
  type        = string
  default     = ""
}

variable "cicd_state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform remote state"
  type        = string
  default     = ""
}
