terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  default_tags {
    tags = {
      Environment = var.environment
      System      = "Internal SPA"
    }
  }
}


#################################################
# Public SPA
#################################################
module "public_spa" {
  source           = "../modules/cloudfront-spa"
  s3_bucket_prefix = var.s3_bucket_prefix
}