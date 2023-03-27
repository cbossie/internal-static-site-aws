resource "aws_s3_bucket" "spa_bucket" {
  bucket_prefix = var.bucket_prefix
}

resource "aws_s3_bucket_policy" "vpce_policy" {
  bucket = aws_s3_bucket.spa_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "VPCEPOLICY"


    Statement = [
      {
        Sid       = "Access-to-specific-VPCE-only"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = [aws_s3_bucket.spa_bucket.arn, "${aws_s3_bucket.spa_bucket.arn}/*"]
        Condition = {
          StringEquals = {
            "aws:SourceVpce" = "${aws_vpc_endpoint.s3_endpoint.id}"
          }
        }
      }
    ]

  })
}









