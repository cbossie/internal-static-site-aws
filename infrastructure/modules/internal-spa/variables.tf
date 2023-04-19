
#General Configuration
variable "appid" {
  type        = string
  description = "The application identifier of this. This will be used as a prefix / tag for created resources"
}
variable "vpc_id" {
  type        = string
  description = "The ID of the VPC in which the SPA will be created"
}

variable "subnets" {
  type        = list(string)
  description = "The subnets where the proxy cluster will be launched"
}

variable "certificate_arn" {
  type        = string
  description = "The ARN of the certificate to associate with the LB"
}

variable "region" {
  type        = string
  description = "The region for this"
}

variable "s3_interface_endpoint_id" {
  type        = string
  description = "The VPC endpoint for S3 for this proxy."
}

variable "allow_http" {
  type        = bool
  description = "Whether to use the plain http backend"
  default     = false
}

variable "private_zone_id" {
  type        = string
  description = "Route53 Private zone"
}

variable "use_ecs_public_ip" {
  type        = bool
  description = "Whether or not to give the ECS services a public IP. If they are deployed to a public subnet, they will need this"
  default     = false
}

variable "bucket_prefix" {
  type        = string
  description = "The bucket prefix for the s3 bucket hosting the site"
  default     = "private-spa-"
}
