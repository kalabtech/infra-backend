output "dynamodb_table" {
  value       = aws_dynamodb_table.this.name
  description = "DynamoDB name for backend.hcl"
}
