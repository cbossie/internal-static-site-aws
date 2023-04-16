#AZs is only referenced if we are using a new VPC

locals {
  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  private_subnets = var.use_existing_vpc ? var.existing_subnets : slice(cidrsubnets(var.cidr_block, 8, 8, 8, 8, 8, 8), 0, 3)
  public_subnets  = slice(cidrsubnets(var.cidr_block, 8, 8, 8, 8, 8, 8), 3, 6)
  s3_service      = "com.amazonaws.${var.region}.s3"
  cidr_block      = var.use_existing_vpc ? data.aws_vpc.existing_vpc.cidr_block : var.cidr_block

  vpc_id      = var.use_existing_vpc ? var.vpc_id : one(module.vpc).vpc_id
  s3_endpoint = aws_vpc_endpoint.s3_endpoint.id


}

module "vpc" {
  source               = "terraform-aws-modules/vpc/aws"
  azs                  = local.azs
  name                 = "${var.appid}-vpc"
  cidr                 = var.cidr_block
  private_subnets      = local.private_subnets
  public_subnets       = local.public_subnets
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_support   = true
  enable_dns_hostnames = true
  count                = !var.use_existing_vpc ? 1 : 0
}

data "aws_vpc" "existing_vpc" {
  id = local.vpc_id
}

resource "aws_security_group" "vpce_sg" {
  name_prefix = "${var.appid}_vpce_sg-"
  vpc_id      = local.vpc_id
  ingress {
    protocol    = -1
    description = "Ingress to LB"
    from_port   = 0
    to_port     = 0
    cidr_blocks = [local.cidr_block]
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
  vpc_id             = local.vpc_id
  service_name       = local.s3_service
  vpc_endpoint_type  = "Interface"
  security_group_ids = [aws_security_group.vpce_sg.id]
  subnet_ids         = local.private_subnets
}



resource "aws_route53_zone" "privatezone" {
  name = var.domain_name
  vpc {
    vpc_id = local.vpc_id
  }
}