##############################################################
#General Configuration - These defaults are OK for basic Setup
##############################################################
variable "s3_bucket_prefix" {
  type        = string
  description = "The S3 bucket Prefix"
}

variable "environment" {
  type        = string
  description = "The environment name"
  default = "dev"
}