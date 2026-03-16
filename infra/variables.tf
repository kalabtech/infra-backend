variable "aws_profile" {
  description = "AWS CLI profile to use for authentication"
  type        = string
  default     = null
}

variable "project_name" {
  type = string
  default = "Infra-Backend"
}

variable "aws_region" {
  description = "AWS Region for provider"
  type        = string
  default     = "eu-west-1"
}
