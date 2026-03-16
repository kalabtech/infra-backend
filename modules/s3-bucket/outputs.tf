output "bucket_name" {
  value       = aws_s3_bucket.this.id
  description = "Bucket name for backend.hcl"
}
