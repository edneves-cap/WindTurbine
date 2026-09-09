# Setup
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = " ~> 6.0"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }

    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
  required_version = ">= 1.2.0"

  backend "s3" {}
}


## modules
module "s3_bucket" {
  source = "./modules/s3/s3_bucket_upload"
  #for_each = [ "raw", "processed" ]
  #bucket_name = "each.key"
  bucket_name = var.bucket_name

  #environment = var.environment
  #version = var.version
}

module "vpc" {
  source     = "./modules/vpc"
  name       = "windturbine-vpc"
  cidr_block = "10.0.0.0/16"
  az_count   = 2
}

module "rds" {
  source = "./modules/rds"

  instance_class = "db.t3.micro"
  db_name        = "windturbine"
  db_username    = "gis_admin"
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnet_ids
}

module "cicd" {
  count = var.enable_cicd ? 1 : 0

  source = "./modules/cicd"

  name                 = "windturbine"
  artifact_bucket_name = var.cicd_artifact_bucket_name
  state_bucket_name    = var.cicd_state_bucket_name
  connection_name      = "windturbine-gitlab"
  gitlab_repository    = var.gitlab_repository
  source_branch        = "dev"
  environments         = ["dev", "prod"]
}
/*
module "lambda" {
    source = "./modules/lambda"

    aws_s3_bucket_arn = module.s3_bucket.aws_s3_bucket_arn
    aws_s3_bucket_id  = module.s3_bucket.aws_s3_bucket_id

    rds_endpoint = module.rds.rds_address
    rds_name     = module.rds.db_name
    rds_username = module.rds.db_username
    rds_password = module.rds.rds_password
    rds_address  = module.rds.rds_address

    aws_db_subnet_group_id = module.rds.aws_db_subnet_group_id
    aws_security_group_id   = module.rds.aws_security_group_id
    efs_file_system_id = module.efs.efs_file_system_id
    efs_access_point_arn = module.efs.efs_access_point_arn
    db_secret_arn = module.rds.db_secret_arn
}


module "vpc" {
    source = "./modules/vpc"
    name   = "windturbine-vpc"
    cidr_block = "10.0.0.0/16"
    az_count = 2
}



module "efs" {
    source = "./modules/efs"

    name = "windturbine-efs"
    vpc_id = module.vpc.vpc_id
    subnet_ids = module.vpc.private_subnet_ids
    lambda_security_group_id = module.rds.aws_security_group_id
}



*/