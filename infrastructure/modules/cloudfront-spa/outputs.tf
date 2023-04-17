output "cf_url" {
    description = "Cloudfront Distribution URL"
    value = aws_cloudfront_distribution.spa_distribution.domain_name
}

output "public_spa_bucket" {
    description = "The bucket where the public SPA will be stored"
    value = aws_s3_bucket.spa_files_bucket.id
}