output "instance_id" {
  value = aws_instance.app.id
}

output "instance_public_ip" {
  value = aws_instance.app.public_ip
}

output "vpc_id_from_remote_state" {
  description = "Proves the value actually came from network/'s state, not hardcoded here"
  value       = data.terraform_remote_state.network.outputs.vpc_id
}
