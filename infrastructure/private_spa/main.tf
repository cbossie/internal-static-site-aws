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
# Private SPA
#################################################
resource "aws_acm_certificate" "lb_cert" {
  private_key      = file("cert/sample-private-key.pem")
  certificate_body = file("cert/sample-certificate.pem")
}

#Creeate the SPA proxy
#Data comes from the "vpc.tf" file
module "spa_proxy" {
  source                   = "../modules/internal-spa"
  appid                    = var.appid
  vpc_id                   = local.vpc_id
  subnets                  = local.private_subnets
  certificate_arn          = aws_acm_certificate.lb_cert.arn
  allow_http               = false
  region                   = var.region
  s3_interface_endpoint_id = local.s3_endpoint
  private_zone_id          = aws_route53_zone.privatezone.id
  use_ecs_public_ip        = var.existing_subnets_are_public
  depends_on = [
    aws_acm_certificate.lb_cert,
    aws_route53_zone.privatezone,
    aws_vpc_endpoint.s3_endpoint,
    module.vpc
  ]
}

