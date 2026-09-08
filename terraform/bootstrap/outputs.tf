output "state_bucket" {
  description = "S3 bucket used for Terraform remote state"
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN of the remote state bucket"
  value       = aws_s3_bucket.state.arn
}

output "lock_table" {
  description = "DynamoDB table used for state locking"
  value       = aws_dynamodb_table.lock.id
}
