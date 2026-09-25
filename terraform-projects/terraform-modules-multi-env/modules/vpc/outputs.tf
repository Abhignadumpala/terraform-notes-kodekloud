# VPC id — the security group module needs this

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.nginx_vpc.id
}

# Subnet id — the EC2 module needs this

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public_subnet.id
}
