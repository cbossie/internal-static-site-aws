##############################################################
#General Configuration - These defaults are OK for basic Setup
##############################################################
variable "environment" {
  type        = string
  description = "The environment name"
}

variable "bucket_prefix" {
  type        = string
  description = "S3 Bucket Prefix For the single-page-app"
  default     = "spa-"
}

# You MUST fill this in
variable "region" {
  type        = string
  description = "The region for this SPA"
}

variable "appid" {
  type        = string
  description = "Application ID for this"
  default     = "spa"
}

variable "domain_name" {
  type        = string
  description = "Domain name for this site"
  default     = "samplesite.local"
}

##############################################################
#VPC Configuration - Set up the networking
##############################################################

#EXISTING VPC SETTINGS
variable "use_existing_vpc" {
  type        = bool
  description = "Determines if you will deploy this into an existing VPC"
  default     = false
}

variable "vpc_id" {
  type        = string
  description = "If you are using an existing vpc, populate it here"
  default     = "vpc-xxxxxxxxxxxxx"
}

variable "existing_subnets" {
  type        = list(string)
  description = "If you are using an existing VPC, then this should be the load balancer subnets"
  default     = []
}

variable "existing_subnets_are_public" {
  type        = bool
  description = "if you are deploying to public subnets, set this to true. Even though the service will be internal only, it will allow ECS to retrieve container images"
  default     = false
}

#NEW VPC SETTINGS

# If you create a vpc then you must use this
variable "cidr_block" {
  type        = string
  description = "The cidr block of the created vpc"
  default     = "10.0.0.0/16"
}








