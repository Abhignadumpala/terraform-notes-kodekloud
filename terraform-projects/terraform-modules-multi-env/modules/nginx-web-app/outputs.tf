# Pass the useful values up to the environment

output "public_ip" {
  value = module.ec2.public_ip
}

output "instance_id" {
  value = module.ec2.instance_id
}

output "nginx_url" {
  value = "http://${module.ec2.public_ip}"
}