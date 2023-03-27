output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "The Created VPC"
}

output "vpc_endpoints" {
  value = replace(aws_vpc_endpoint.s3_endpoint.dns_entry[0].dns_name,"*","bucket")
  description = "VPC URL"
}


output "vpc_endpoint_id" {
  value = aws_vpc_endpoint.s3_endpoint.id
  description = "VPC Endpoint ID"
}