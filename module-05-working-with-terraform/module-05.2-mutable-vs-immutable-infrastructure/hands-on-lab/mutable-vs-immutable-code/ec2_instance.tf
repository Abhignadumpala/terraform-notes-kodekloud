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

# swap-to AMI for Part 2. `ami` is a ForceNew attribute on aws_instance, so
# pointing at a different AMI (unlike instance_type) actually replaces the
# instance instead of resizing it in place.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "web_server" {
  ami           = data.aws_ami.ubuntu.id  # change to data.aws_ami.ubuntu.id for Part 2
  instance_type = "t2.micro"

  tags = {
    Name        = "web-server-v2" # changed to web-server-v1 to web-server-v2 for Part 1
    Environment = "lab"
    Project     = "mutable-vs-immutable"
  }
}
