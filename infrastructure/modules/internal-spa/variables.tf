variable "vpc_id" {
    type = string
    description = "The ID of the VPC in which the SPA will be created"
}

variable "subnets" {
  type = list(string)
  description = "The subnets where the proxy cluster will be launched"
}

variable "certificate_arn" {
    type = string
    description = "The ARN of the certificate to associate with the LB"
}