# Security group — the firewall around my EC2 instance

resource "aws_security_group" "nginx_sg" {
  name        = "${var.environment}-nginx-sg"
  description = "Allow HTTP and SSH to the nginx server"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.environment}-nginx-sg"
  }
}

# Inbound HTTP (port 80) from anywhere — so anyone can open the nginx page

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.nginx_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# Inbound SSH (port 22) only from my IP — never open SSH to the whole internet

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.nginx_sg.id
  cidr_ipv4         = var.ssh_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

# Outbound — allow everything, so EC2 can download nginx and updates

resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.nginx_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # -1 means all protocols and all ports
}