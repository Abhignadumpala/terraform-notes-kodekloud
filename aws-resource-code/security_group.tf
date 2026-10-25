# Security group: a firewall around the EC2 instance.
# Each rule is its own resource (one CIDR per rule). I don't put ingress/egress blocks inside aws_security_group,
# and I don't mix both styles - mixing them makes Terraform fight over the rules.

resource "aws_security_group" "web" {
  name        = "Mr_cloud_web_sg"
  description = "Allow SSH and HTTP in, everything out"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "Mr_cloud_web_sg"
  }
}

# Inbound: SSH (22). In real use I'd put my own IP here, like "1.2.3.4/32", not the whole internet.

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

# Inbound: HTTP (80) from anywhere, for a website.

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# Outbound: everything. "-1" means all protocols and all ports.

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
