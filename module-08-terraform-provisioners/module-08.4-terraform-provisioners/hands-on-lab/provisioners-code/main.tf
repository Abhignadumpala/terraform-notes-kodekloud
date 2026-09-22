# Same modernizations as 8.3: data-sourced AMI, t3.micro, separate SG rule
# resources - the point of this lab is provisioners, not re-litigating those.

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# file(), not tls_private_key - see the note on the connection block below
# for why this has to be a key generated *before* this apply runs, not one
# Terraform generates as part of it.
resource "aws_key_pair" "web" {
  key_name   = "module-08-4-provisioners-key"
  public_key = file("${path.module}/web.pub")
}

resource "aws_security_group" "ssh_access" {
  name        = "module-08-4-ssh-access"
  description = "Allow SSH access from the Internet"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.ssh_access.id
  description       = "SSH - demo only"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.ssh_access.id
  description       = "All outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# remote-exec + connection block - installs nginx over SSH instead of
# baking it into user_data, the thing this whole module is comparing
# against 8.3's native approach.
resource "aws_instance" "webserver" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.web.key_name
  vpc_security_group_ids = [aws_security_group.ssh_access.id]

  tags = {
    Name        = "webserver-provisioners"
    Description = "nginx installed via remote-exec, not user_data"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install nginx -y",
      "sudo systemctl enable nginx",
      "sudo systemctl start nginx",
    ]
  }

  # Both the type and the file() argument here are literals, not references
  # to another resource's attribute - required, since this resource also
  # has a destroy-time provisioner below, and a destroy-time provisioner's
  # connection block may only reference `self`/`count.index`/`each.key`.
  # web/web.pub were generated with `ssh-keygen` before this apply ran -
  # file() reads from disk at plan time, so the key has to already exist;
  # it can't be a resource this same configuration creates.
  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file("${path.module}/web")
  }

  # local-exec, create-time - runs on this machine, not the instance
  provisioner "local-exec" {
    command = "echo Instance ${self.public_ip} Created! > ${path.module}/instance_state.txt"
  }

  # local-exec, destroy-time - self.public_ip still resolves from state
  provisioner "local-exec" {
    when    = destroy
    command = "echo Instance ${self.public_ip} Destroyed! > ${path.module}/instance_state.txt"
  }
}
