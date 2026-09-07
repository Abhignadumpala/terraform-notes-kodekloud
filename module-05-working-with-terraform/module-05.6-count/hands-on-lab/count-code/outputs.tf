output "web_server_ids" {
  value = aws_instance.web[*].id
}

output "web_server_names_by_index" {
  value = { for i, server in aws_instance.web : i => server.tags["Name"] }
}

output "first_instance_id" {
  value = aws_instance.web[0].id
}
