output "vpc_id" {
  value       = var.use_existing_vpc ? var.vpc_id : one(module.vpc).vpc_id
  description = "The Created VPC"
}

output "vpc_endpoints" {
  value       = replace(aws_vpc_endpoint.s3_endpoint.dns_entry[0].dns_name, "*", "bucket")
  description = "VPC URL"
}


output "vpc_endpoint_id" {
  value       = aws_vpc_endpoint.s3_endpoint.id
  description = "VPC Endpoint ID"
}

output "subnets" {

  value = {
    private = local.private_subnets
    public  = local.public_subnets
  }
} 