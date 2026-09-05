output "instance_id" {
  value = aws_instance.state_lab.id
}

output "instance_public_ip" {
  value = aws_instance.state_lab.public_ip
}
