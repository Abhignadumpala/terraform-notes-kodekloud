output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app.id
}

output "instance_type" {
  description = "EC2 instance type - t2.micro for dev, t2.medium for prod"
  value       = aws_instance.app.instance_type
}

output "environment" {
  description = "Environment this instance was deployed for"
  value       = var.environment
}
