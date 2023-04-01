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
variable "cidr_block" {
  type = string
  description = "The cidr block of the created vpc"
  default = "10.0.0.0/16"
}

variable "domain_name" {
  type = string
  description = "Domain name for this site"
  default = "samplesite.local"
}

variable "appid" {
  type = string
  description = "Application ID for this"
  default = "spa"
}