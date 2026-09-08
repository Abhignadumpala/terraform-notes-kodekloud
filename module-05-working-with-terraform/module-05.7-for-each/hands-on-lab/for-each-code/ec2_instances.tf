# Demonstrates the for_each meta-argument, keyed directly by the values
# in var.web_server_names. Unlike the count lab, removing a name from
# this set should touch only the one instance whose key was removed —
# nothing shifts.
resource "aws_instance" "web" {
  for_each      = var.web_server_names
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  tags = {
    Name    = each.value
    Project = "for-each-lab"
  }
}
