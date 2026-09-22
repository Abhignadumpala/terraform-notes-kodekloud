output "public_ip" {
  description = "Public IP of the webserver instance"
  value       = aws_instance.webserver.public_ip
}

output "ami_id_used" {
  description = "Whatever Ubuntu 24.04 AMI the data source resolved to, at apply time"
  value       = data.aws_ami.ubuntu.id
}

output "ssh_private_key" {
  description = "Private half of the generated key pair - save to a file and chmod 600 to actually SSH in"
  value       = tls_private_key.web.private_key_openssh
  sensitive   = true
}
