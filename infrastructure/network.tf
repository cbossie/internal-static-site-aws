locals {
  azs        = ["${var.region}a", "${var.region}b", "${var.region}c"]
  s3_service = "com.amazonaws.${var.region}.s3"
  cidr       = "10.0.0.0/16"


}


module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  azs                  = local.azs
  name                 = "proxy-vpc"
  cidr                 = local.cidr
  private_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets       = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_security_group" "all_vpc_sg" {
  name_prefix = "internal-spa-sg"
  vpc_id      = module.vpc.vpc_id
  ingress {
    protocol    = -1
    description = "All VPC Ingress"
    from_port   = 0
    self        = true
    to_port     = 0
    cidr_blocks = [local.cidr]
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
  security_group_ids = [aws_security_group.all_vpc_sg.id]
  subnet_ids         = module.vpc.private_subnets
}



