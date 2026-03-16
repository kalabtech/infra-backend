variable "aws_profile" {
  description = "AWS CLI profile to use for authentication"
  type        = string
  default     = null
}

variable "project_name" {
  type    = string
  default = "Infra-Backend"
}

variable "aws_region" {
  description = "AWS Region for provider"
  type        = string
  default     = "eu-west-1"
}

variable "bucket_name" {
  description = "AWS S3 tfstate bucket name"
  type        = string
}

variable "kms_alias_name" {
  description = "AWS KMS alias name"
  type        = string
}
