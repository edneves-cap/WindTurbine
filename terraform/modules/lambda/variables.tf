variable "lambda_function_name" {
  type      = string
  sensitive = false
  default   = "read_and_treat_agri_data"
}

variable "aws_s3_bucket_arn" {
  type      = string
  sensitive = false

}

variable "aws_s3_bucket_id" {
  type      = string
  sensitive = false

}

variable "rds_endpoint" {
  type      = string
  sensitive = false

}

variable "rds_name" {
  type      = string
  sensitive = false

}
variable "rds_username" {
  type      = string
  sensitive = false

}
variable "rds_password" {
  type      = string
  sensitive = false
}

variable "rds_address" {
  type      = string
  sensitive = false
}

variable "aws_db_subnet_group_id" {

}

variable "aws_security_group_id" {

}

variable "efs_file_system_id" {
  type    = string
  default = ""
}

variable "efs_access_point_arn" {
  type    = string
  default = ""
}

variable "db_secret_arn" {
  type    = string
  default = ""
}

