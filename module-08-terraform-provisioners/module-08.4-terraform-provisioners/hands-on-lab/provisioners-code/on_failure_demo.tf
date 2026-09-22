# Isolated from the EC2 resources above on purpose - a null_resource is
# Terraform's standard tool for a provisioner with nothing real to attach
# to, and keeps this demo from needing any AWS resource at all.

resource "null_resource" "on_failure_demo" {
  provisioner "local-exec" {
    on_failure = continue
    command    = "echo this fails on purpose > /no/such/directory/state.txt"
  }

  provisioner "local-exec" {
    command = "echo second provisioner ran anyway, on_failure = continue worked > ${path.module}/on_failure_state.txt"
  }
}
