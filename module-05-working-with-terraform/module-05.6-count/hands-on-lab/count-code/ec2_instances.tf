# Demonstrates the count meta-argument, driven by the length of
# var.web_server_names. To trigger the index-shifting pitfall from the
# module notes: remove the first element from that list's default (or
# a *.tfvars override) and re-run `terraform plan`.
resource "aws_instance" "web" {
  count         = length(var.web_server_names)
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  tags = {
    Name    = var.web_server_names[count.index]
    Project = "count-lab"
  }
}
