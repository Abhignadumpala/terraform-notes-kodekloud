output "table_name" {
  description = "Name of the employee_data DynamoDB table"
  value       = aws_dynamodb_table.employee_data.name
}

output "table_arn" {
  description = "ARN of the employee_data DynamoDB table"
  value       = aws_dynamodb_table.employee_data.arn
}

output "billing_mode" {
  description = "Billing mode the table was created with"
  value       = aws_dynamodb_table.employee_data.billing_mode
}
