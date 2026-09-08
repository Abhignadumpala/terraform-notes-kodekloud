output "web_server_ids" {
  value = { for name, server in aws_instance.web : name => server.id }
}

output "web_server_names_by_key" {
  value = { for name, server in aws_instance.web : name => server.tags["Name"] }
}

output "web_prod_2_instance_id" {
  value = aws_instance.web["web-prod-2"].id
}
