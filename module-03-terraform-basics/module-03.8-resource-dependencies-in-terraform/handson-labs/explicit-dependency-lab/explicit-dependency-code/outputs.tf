output "iam_role_name" {
  value = aws_iam_role.ec2_role.name
}

output "instance_id" {
  value = aws_instance.app_server.id
}

output "instance_public_ip" {
  value = aws_instance.app_server.public_ip
}
