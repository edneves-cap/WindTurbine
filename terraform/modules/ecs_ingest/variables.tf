variable "s3_bucket_name" {
  type = string
}

variable "s3_bucket_arn" {
  type = string
}

variable "s3_prefix" {
  type    = string
  default = "unzipped/"
}

variable "db_secret_arn" {
  type = string
}

variable "db_conn_string" {
  type    = string
  default = ""
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}
