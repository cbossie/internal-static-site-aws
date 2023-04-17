#S3 Items - Buckety Policy etc

locals {
  s3_origin_id = "public_spa-${aws_s3_bucket.spa_files_bucket.id}"
}

resource "aws_s3_bucket" "spa_files_bucket" {
  bucket_prefix = var.s3_bucket_prefix
}

resource "aws_s3_object" "index_file" {
  source = "${path.module}/assets/index.html"
  bucket = aws_s3_bucket.spa_files_bucket.id
  key    = "index.html"
  content_type = "text/html"
}


data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.spa_files_bucket.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.spa_distribution.arn]
    }

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]

    }
  }
}

resource "aws_s3_bucket_policy" "cf_access_policy" {
  bucket = aws_s3_bucket.spa_files_bucket.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

# Cloudfront Items
resource "aws_cloudfront_origin_access_control" "s3_access_policy" {
  name                              = "s3accesspolicy"
  description                       = "Origina access policy"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_access_identity" "spa_identity" {
  comment = "The access identity for this distribution"
}

#cloudfront
resource "aws_cloudfront_distribution" "spa_distribution" {
  origin {
    domain_name              = aws_s3_bucket.spa_files_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_access_policy.id
    origin_id = local.s3_origin_id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Public_SPA_Distribution"
  default_root_object = "index.html"

  default_cache_behavior {
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.s3_origin_id
    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

}


#Web Application Firewall




