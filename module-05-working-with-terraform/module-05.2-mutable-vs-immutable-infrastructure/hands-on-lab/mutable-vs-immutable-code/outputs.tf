output "instance_id" {
  value = aws_instance.web_server.id
}

output "instance_type" {
  value = aws_instance.web_server.instance_type
}

output "instance_public_ip" {
  value = aws_instance.web_server.public_ip
}

output "instance_tags" {
  value = aws_instance.web_server.tags
}
