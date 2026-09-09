variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "postgres"
}

variable "db_username" {
  description = "DB admin username"
  type        = string
  default     = "gis_admin"
}

variable "vpc_id" {
  description = "VPC id to deploy RDS into"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet ids for the DB subnet group"
  type        = list(string)
}
