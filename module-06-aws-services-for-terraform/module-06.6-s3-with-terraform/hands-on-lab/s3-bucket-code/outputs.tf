output "bucket_name" {
  description = "Name of the finance S3 bucket"
  value       = aws_s3_bucket.finance.id
}

output "bucket_arn" {
  description = "ARN of the finance S3 bucket"
  value       = aws_s3_bucket.finance.arn
}

output "object_key" {
  description = "Key of the uploaded finance object"
  value       = aws_s3_object.finance_2020.key
}

output "finance_analysts_group_arn" {
  description = "ARN of the finance-analysts IAM group"
  value       = aws_iam_group.finance_analysts.arn
}

output "finance_analysts_member_arns" {
  description = "ARNs of finance-analysts members, granted access by the bucket policy"
  value       = data.aws_iam_group.finance_analysts.users[*].arn
}
