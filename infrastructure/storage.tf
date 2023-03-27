resource "aws_s3_bucket" "spa_bucket" {
  bucket_prefix = var.bucket_prefix
}