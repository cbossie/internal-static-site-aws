# Add outputs here

output "spa_bucket" {
  description = "The bucket name for the SPA files"
  value       = aws_s3_bucket.spa_bucket.id
}

output "load_balancer_url" {
  description = "The load balancer URL"
  value       = aws_lb.proxy_lb.dns_name
}