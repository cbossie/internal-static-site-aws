terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"

    }
  }
  backend "s3" {
  }

}

provider "aws" {
  default_tags {
    tags = {
      Environment = var.environment
      System      = "internal SPA"
    }
  }
}


locals {
  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  s3_service      = "com.amazonaws.${var.region}.s3"
  cidr            = "10.0.0.0/16"
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}


module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  azs                  = local.azs
  name                 = "proxy-vpc"
  cidr                 = local.cidr
  private_subnets      = local.private_subnets
  public_subnets       = local.public_subnets
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_support   = true
  enable_dns_hostnames = true
}


resource "aws_security_group" "vpce_sg" {
  name_prefix = "vpce_sg"
  vpc_id      = module.vpc.vpc_id
  ingress {
    protocol    = -1
    description = "Ingress to LB"
    from_port   = 0
    to_port     = 0
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_vpc_endpoint" "s3_endpoint" {
  tags = {
    "Name" = "S3 Endpoint"
  }
  vpc_id             = module.vpc.vpc_id
  service_name       = local.s3_service
  vpc_endpoint_type  = "Interface"
  security_group_ids = [aws_security_group.vpce_sg.id]
  subnet_ids         = module.vpc.private_subnets
}



resource "aws_acm_certificate" "lb_cert" {
  private_key      = file("cert/sample-private-key.pem")
  certificate_body = file("cert/sample-certificate.pem")
}

resource "aws_route53_zone" "privatezone" {
  name = "samplesite.local"
  vpc {
    vpc_id = module.vpc.vpc_id
  }
}

#Creeate the SPA proxy
module "spa_proxy" {
  source                   = "./modules/internal-spa"
  appid                    = "spa"
  vpc_id                   = module.vpc.vpc_id
  subnets                  = module.vpc.private_subnets
  certificate_arn          = aws_acm_certificate.lb_cert.arn
  allow_http               = true
  region                   = var.region
  s3_interface_endpoint_id = aws_vpc_endpoint.s3_endpoint.id
  private_zone_id          = aws_route53_zone.privatezone.id
  depends_on = [
    aws_acm_certificate.lb_cert,
    aws_route53_zone.privatezone,
    aws_vpc_endpoint.s3_endpoint,
    module.vpc
  ]

}