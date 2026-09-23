# 📘 Module 8.6: Considerations with Provisioners

> [8.4](../module-08.4-terraform-provisioners/README.md) covered the mechanics — `remote-exec`, `local-exec`, `on_failure`. This is the step back: what a provisioner costs me even when it works, and the ladder of alternatives that get further and further away from needing one at all.

---

## Why I Use Provisioners Sparingly

A provisioner runs an arbitrary, system-supported command — which is exactly what makes it costly. Terraform's `plan` works by comparing declared configuration against state; a provisioner's command is opaque to that comparison, so `plan` can't predict or validate what it'll actually do. Two direct consequences: the configuration gets harder to reason about the more provisioners it carries, and `plan` stops being a reliable preview of everything that's about to happen.

```hcl
resource "aws_instance" "webserver" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  tags = {
    Name        = "webserver"
    Description = "An NGINX WebServer on Ubuntu"
  }

  provisioner "remote-exec" {
    inline = ["echo $(hostname -i) >> /tmp/ips.txt"]
  }
}
```

> 💡 `hostname -i` is a shortcut, not a reliable one — depending on the AMI and how its network interfaces are set up, it can return a loopback address or the wrong interface entirely. Reading from the instance metadata service is the dependable way to get an instance's own private IP from inside itself: `curl http://169.254.169.254/latest/meta-data/local-ipv4`.

---

## The Connection Block Isn't Optional

`remote-exec` needs a `connection` block — without one, Terraform has no way to know how to reach the instance:

```hcl
resource "aws_instance" "webserver" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  tags = {
    Name        = "webserver"
    Description = "An NGINX WebServer on Ubuntu"
  }

  provisioner "remote-exec" {
    inline = ["echo $(hostname -i) >> /tmp/ips.txt"]
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file("${path.module}/web")
  }

  key_name               = aws_key_pair.web.key_name
  vpc_security_group_ids = [aws_security_group.ssh_access.id]
}
```

That's [8.4](../module-08.4-terraform-provisioners/README.md#remote-exec-running-commands-on-the-resource-itself)'s setup in full: the key pair registered, the security group actually allowing SSH in, and the connection block itself — all three, every time, or `remote-exec` has nothing to connect through.

---

## Best Practice: Resource-Native Features First

Same conclusion as [8.4](../module-08.4-terraform-provisioners/README.md#best-practice-prefer-native-resource-capabilities): `user_data` does this exact nginx install without a connection block, an SSH key, or a security group rule for port 22 at all.

```hcl
resource "aws_instance" "webserver" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  tags = {
    Name        = "webserver"
    Description = "An NGINX WebServer on Ubuntu"
  }
  user_data = <<-EOF
    #!/bin/bash
    sudo apt update
    sudo apt install nginx -y
    systemctl enable nginx
    systemctl start nginx
  EOF
}
```

Leaning on provisioners for routine post-launch setup, even the native ones like `user_data`, still risks configuration drift over time — every instance re-runs that install script fresh on every launch, which is one more thing that can behave differently between launches as upstream packages change.

---

## Further Still: Bake It Into the Image

The next rung up the ladder skips post-launch setup entirely — build an AMI that already has nginx installed, and just launch it:

```hcl
resource "aws_instance" "webserver" {
  ami           = "ami-0123456789abcdef0" # a custom AMI, nginx already installed
  instance_type = "t3.micro"
  tags = {
    Name        = "webserver"
    Description = "An NGINX WebServer on Ubuntu"
  }
}
```

No provisioner, no `user_data`, nothing to run at launch at all — the instance boots already in its final state. Two tools build that AMI:

- **[Packer](https://developer.hashicorp.com/packer)** — HashiCorp's own image-building tool, declarative, and the natural fit when the same image needs to land on more than one cloud (AWS, Azure, GCP) from one definition.
- **[AWS EC2 Image Builder](https://docs.aws.amazon.com/imagebuilder/)** — AWS's own managed pipeline for building, testing, and distributing AMIs, with built-in scheduling and integration into EventBridge/SNS/Systems Manager. For an AWS-only setup, this is usually the simpler starting point over Packer, since there's no separate build tool or pipeline to run and maintain — Packer's advantage shows up specifically when the same image needs to work across more than one cloud provider.

Either way, the resulting AMI ID just gets referenced directly, same as any other AMI.

---

## Summary

- ✅ A provisioner's command is opaque to `plan` — it can't be validated or previewed the way a resource attribute change can
- ⚠️ `hostname -i` isn't a reliable way to get an instance's own IP from inside itself — the instance metadata service (`169.254.169.254`) is
- ✅ `remote-exec` needs all three every time: a security group rule allowing the connection, a registered key pair, and the `connection` block itself
- ✅ `user_data` skips the connection requirements entirely, but still re-runs its setup script on every launch
- ✅ A custom AMI (via Packer or EC2 Image Builder) skips post-launch setup altogether — the instance boots already configured
- ✅ EC2 Image Builder is the simpler choice for an AWS-only pipeline; Packer's advantage is multi-cloud image definitions

---

## Key Takeaway

**Three tiers, each one further from needing a provisioner at all: `remote-exec` (runs every launch, needs a live connection), `user_data` (runs every launch, no connection needed), a custom AMI (doesn't run anything at launch — it's already done).**

- ✅ Climbing this ladder trades build-time complexity (maintaining an image pipeline) for launch-time simplicity and reliability
- ⚠️ Even `user_data` isn't fully drift-proof — it re-executes the same script on every single launch, picking up whatever the upstream packages look like that day

---

## Practice & Next Steps

Take [8.4](../module-08.4-terraform-provisioners/README.md)'s hands-on lab instance and compare boot time and reliability across all three tiers: `remote-exec` (needs the connection to succeed before nginx even starts installing), `user_data` (already tested), and — if a Packer or EC2 Image Builder pipeline is available — an AMI with nginx pre-baked in, timing how much faster the instance is actually ready to serve traffic.

That closes out the planned lessons for Module 8.
