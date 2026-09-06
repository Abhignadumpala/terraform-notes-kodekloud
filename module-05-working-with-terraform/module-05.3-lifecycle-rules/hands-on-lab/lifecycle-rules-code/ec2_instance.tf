# Demonstrates create_before_destroy and ignore_changes on the same instance.
#
# - create_before_destroy: swap the AMI below (amazon_linux -> ubuntu) to force
#   a replacement, and watch the plan show `+/-` (create first) instead of the
#   default `-/+` (destroy first).
# - ignore_changes: change this instance's Name tag from the AWS console or
#   CLI (not from this file), then run `terraform plan` - it should come back
#   clean instead of trying to revert the tag.

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

# swap-to AMI to trigger the create_before_destroy replacement. `ami` is a
# ForceNew attribute on aws_instance - changing it always replaces the
# instance, unlike something like instance_type modifications.
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

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id # change to data.aws_ami.ubuntu.id to force a replacement
  instance_type = "t2.micro"

  tags = {
    Name    = "lifecycle-rules-lab"
    Project = "lifecycle-rules-lab"
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [tags]
  }
}
