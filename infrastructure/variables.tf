variable "environment" {
  type        = string
  description = "The environment name"
}

variable "region" {
  type        = string
  description = "The region for this SPA"
}

variable "bucket_prefix" {
  type        = string
  description = "S3 Bucket Prefix"
}