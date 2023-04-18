output "external_site_url" {
  description = "The external site's Cloudfront distribution URL"
  value       = "https://${module.public_spa.cf_url}"
}

output "external_site_bucket" {
  description = "The external site's S3 Bucket"
  value       = module.public_spa.public_spa_bucket
}

output "cloudfront_distribution_id" {
  description = "The ID of the created cloudfront distribution"
  value       = module.public_spa.cloudfront_distribution_id
}