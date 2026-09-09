# Setup
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = " ~> 6.0"
    }

    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
  required_version = ">= 1.2.0"
}


## modules
module "s3" {
  source = "././modules/s3_bucket"


}

