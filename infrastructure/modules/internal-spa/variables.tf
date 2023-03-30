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
  type = string
  description = "The VPC endpoint for S3 for this proxy."
}

variable "private_subnet_ids" {
  type = list(string)
  description = "The subnet IDs that the proxies will be launched into"
}