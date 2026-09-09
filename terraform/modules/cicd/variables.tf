variable "name" {
  type = string
}

variable "artifact_bucket_name" {
  type = string
}

variable "state_bucket_name" {
  type = string
}

variable "connection_name" {
  type = string
}

variable "gitlab_repository" {
  description = "GitLab repository in namespace/project format"
  type        = string
}

variable "source_branch" {
  description = "GitLab branch whose artifact enters the promotion pipeline"
  type        = string
  default     = "dev"
}

variable "environments" {
  type = set(string)
}

variable "notification_email" {
  type    = string
  default = "eduardo.a.neves@capgemini.com"
}