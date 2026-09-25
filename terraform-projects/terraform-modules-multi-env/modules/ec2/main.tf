# Find the latest Amazon Linux 2023 AMI — no hardcoded AMI id

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# EC2 instance — the nginx web server

resource "aws_instance" "nginx_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = var.instance_profile_name
  key_name               = var.key_name # null = no SSH key, use Session Manager

  # Only accept IMDSv2 tokens — safer instance metadata
  metadata_options {
    http_tokens = "required"
  }

  # Runs once on first boot — installs nginx and makes a simple page
  user_data = <<-EOF
    #!/bin/bash
    dnf install -y nginx
    echo "<h1>Hello from ${var.environment} nginx</h1>" > /usr/share/nginx/html/index.html
    systemctl enable --now nginx
  EOF

  # If I change user_data, replace the instance so the new script runs
  user_data_replace_on_change = true

  tags = {
    Name = "${var.environment}-nginx-server"
  }
}