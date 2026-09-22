# Owns compute - one EC2 instance - and doesn't declare a single networking
# resource. Everything it needs (subnet, security group) comes from
# network/'s state file, not this config.

data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "tf-remote-state-lab-9506214d"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

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

resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = data.terraform_remote_state.network.outputs.subnet_id
  vpc_security_group_ids = [data.terraform_remote_state.network.outputs.security_group_id]

  tags = {
    Name = "module-07-compute-lab"
  }
}
