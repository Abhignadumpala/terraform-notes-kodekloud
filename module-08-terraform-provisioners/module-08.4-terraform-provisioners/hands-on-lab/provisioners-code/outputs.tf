output "public_ip" {
  value = aws_instance.webserver.public_ip
}

output "ami_id_used" {
  value = data.aws_ami.ubuntu.id
}
