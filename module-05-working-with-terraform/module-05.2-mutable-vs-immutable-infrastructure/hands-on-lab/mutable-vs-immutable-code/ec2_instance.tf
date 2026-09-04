data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "web_server" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro" # change to t2.small for Part 2

  tags = {
    Name        = "web-server-v1" # change to web-server-v2 for Part 1
    Environment = "lab"
    Project     = "mutable-vs-immutable"
  }

  lifecycle {
    # "most_recent" AMI can shift between plan/apply runs - don't let that
    # trigger a replacement that has nothing to do with what I'm testing
    ignore_changes = [ami]
  }
}
