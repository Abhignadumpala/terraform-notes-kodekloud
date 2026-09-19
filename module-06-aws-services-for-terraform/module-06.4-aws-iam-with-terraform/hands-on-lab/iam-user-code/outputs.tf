output "user_arn" {
  description = "ARN of the created IAM user"
  value       = aws_iam_user.admin-user.arn
}

output "user_name" {
  description = "Name of the created IAM user"
  value       = aws_iam_user.admin-user.name
}

output "unique_id" {
  description = "AWS-assigned unique ID for the IAM user"
  value       = aws_iam_user.admin-user.unique_id
}

output "policy_arn" {
  description = "ARN of the AdminUsers policy"
  value       = aws_iam_policy.adminUser.arn
}
