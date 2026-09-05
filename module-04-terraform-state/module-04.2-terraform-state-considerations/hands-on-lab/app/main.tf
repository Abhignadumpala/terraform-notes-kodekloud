# The resource here is incidental - a single free-tier EC2 instance, just so
# there's something real whose state has to live somewhere. The point of this
# lab is where that state lives and how locking behaves, not the instance.
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

resource "aws_instance" "state_lab" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"

  tags = {
    Name    = "s3-backend-state-lab"
    Project = "state-locking-lab"
  }
}
