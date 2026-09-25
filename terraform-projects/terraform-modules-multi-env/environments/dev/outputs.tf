# Public IP of the nginx server

output "public_ip" {
  value = module.nginx_web_app.public_ip
}

# Instance id — for Session Manager and the console

output "instance_id" {
  value = module.nginx_web_app.instance_id
}

# Open this in the browser

output "nginx_url" {
  value = module.nginx_web_app.nginx_url
}