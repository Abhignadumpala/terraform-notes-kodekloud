# Public IP — to open nginx in the browser

output "public_ip" {
  description = "Public IP of the nginx server"
  value       = aws_instance.nginx_server.public_ip
}

# Instance id — handy for Session Manager and the console

output "instance_id" {
  description = "ID of the nginx EC2 instance"
  value       = aws_instance.nginx_server.id
}
