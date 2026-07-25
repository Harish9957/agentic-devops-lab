output "bucket_name" {
  description = "S3 bucket name holding Terraform state — use as `bucket` in dependent use cases' backend.hcl"
  value       = aws_s3_bucket.state.id
}

output "dynamodb_table_name" {
  description = "DynamoDB table name for state locking — use as `dynamodb_table` in dependent use cases' backend.hcl"
  value       = aws_dynamodb_table.locks.name
}
