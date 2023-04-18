output "vpc_id" {
  value       = var.use_existing_vpc ? var.vpc_id : one(module.vpc).vpc_id
  description = "The VPC VPC"
}

output "vpc_endpoints" {
  value       = replace(aws_vpc_endpoint.s3_endpoint.dns_entry[0].dns_name, "*", "bucket")
  description = "VPC Endpoint"
}

output "internal_site_bucket" {
  description = "The bucket that the internal SPA will read from"
  value = module.spa_proxy.spa_bucket
}

output "load_balancer_url" {
  description = "The load balancer URL (for internal use only)"
  value = module.spa_proxy.load_balancer_url
}

output "internal_site_url" {
  description = "The internal site URL"
  value = "https://www.${var.domain_name}"
}