output "vpc_id" {
  description = "VPC ID - read by the compute stack via terraform_remote_state"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "Public subnet ID - read by the compute stack via terraform_remote_state"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "Web security group ID - read by the compute stack via terraform_remote_state"
  value       = aws_security_group.web.id
}
