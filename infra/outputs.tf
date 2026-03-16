output "bucket_name" {
  value       = module.s3-bucket.bucket_name
  description = "Bucket name for backend.hcl"
}

output "kms_key_arn" {
  value       = module.kms.kms_key_arn
  description = "KSM ARN for backend.hcl"
}

output "dynamodb_table" {
  value       = module.dynamoDB.dynamodb_table
  description = "DynamoDB name for backend.hcl"
}
