variable "data_directory" {
  description = "Directory containing CSV data files to upload"
  type        = string
  default = "raw"
}

variable "region" {
    description = "The AWS region to deploy resources in"
    type = string
    default = "us-east-1"
}



variable "db_password" {
    description = "RDS root user password"
    type        = string
    sensitive   = true
    default = "hashicorp"
}
