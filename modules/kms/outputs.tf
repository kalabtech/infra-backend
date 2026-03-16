output "kms_key_arn" {
  value       = aws_kms_key.this.arn
  description = "KSM ARN to encrypt s3 bucket"
}
