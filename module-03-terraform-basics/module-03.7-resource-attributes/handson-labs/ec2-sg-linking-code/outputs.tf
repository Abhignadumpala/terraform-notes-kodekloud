output "security_group_id" {
  description = "Security Group ID"
  value       = aws_security_group.allow_ssh.id
}

output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.web_server.id
}

output "instance_public_ip" {
  description = "Public IP of EC2 Instance"
  value       = aws_instance.web_server.public_ip
}

output "linked_sg_id" {
  description = "Security Group ID attached to instance"
  value       = aws_instance.web_server.vpc_security_group_ids
}
