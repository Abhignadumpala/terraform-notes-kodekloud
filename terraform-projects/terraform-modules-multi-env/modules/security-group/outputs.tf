# SG id — the EC2 module needs this

output "security_group_id" {
  description = "ID of the nginx security group"
  value       = aws_security_group.nginx_sg.id
}