variable "bucket_name" {
  description = "AWS S3 tfstate bucket name"
  type        = string
}

variable "kms_key_arn" {
  description = "AWS KMS key arn to encrypt s3 bucket"
  type        = string
}
