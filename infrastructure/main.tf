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
      System      = "Internal SPA"
    }
  }
}


locals {
  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  s3_service      = "com.amazonaws.${var.region}.s3"
  private_subnets = slice(cidrsubnets(var.cidr_block, 8, 8, 8, 8, 8, 8), 0, 3)
  public_subnets  = slice(cidrsubnets(var.cidr_block, 8, 8, 8, 8, 8, 8), 3, 6)
}


module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  azs                  = local.azs
  name                 = "${var.appid}-vpc"
  cidr                 = var.cidr_block
  private_subnets      = local.private_subnets
  public_subnets       = local.public_subnets
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_support   = true
  enable_dns_hostnames = true
}


resource "aws_security_group" "vpce_sg" {
  name_prefix = "${var.appid}_vpce_sg-"
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
  name = var.domain_name
  vpc {
    vpc_id = module.vpc.vpc_id
  }
}




#Creeate the SPA proxy
module "spa_proxy" {
  source                   = "./modules/internal-spa"
  appid                    = var.appid
  vpc_id                   = module.vpc.vpc_id
  subnets                  = module.vpc.private_subnets
  certificate_arn          = aws_acm_certificate.lb_cert.arn
  allow_http               = false
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




