provider "aws" {
  region  = var.region
  profile = "default"
}

provider "google" {
  #project     = "my-project-id"
  region = var.region
}