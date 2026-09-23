# 📘 Module 8.3: AWS EC2 with Terraform

> [8.1](../module-08.1-introduction-to-aws-ec2/README.md) covered what an EC2 instance actually is. This is deploying one for real: an Ubuntu web server, key-based SSH access, and a security group that actually allows the connection — the running instance that [Module 8](../)'s real subject, provisioners, needs to exist first.

---

## Introduction

Three pieces, three resources: the instance itself (`aws_instance`), an SSH key pair (`aws_key_pair`), and a security group letting SSH traffic in (`aws_security_group` + rule resources). None of them work in isolation — an instance with no key pair can't be SSHed into even with the right security group, and a security group with no ingress rule blocks SSH even with a valid key.

---

## The Instance, with a Looked-Up AMI Instead of a Hardcoded One

```hcl
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

resource "aws_instance" "webserver" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  user_data = <<-EOF
    #!/bin/bash
    sudo apt update
    sudo apt install nginx -y
    systemctl enable nginx
    systemctl start nginx
  EOF

  tags = {
    Name        = "webserver"
    Description = "An Nginx WebServer on Ubuntu"
  }
}
```

> 💡 `data "aws_ami"` with `most_recent = true` finds whatever Canonical's current Ubuntu build actually is, in whatever region the provider is pointed at, every time `plan` runs — the same pattern I already used in [4.2](../../module-04-terraform-state/module-04.2-terraform-state-considerations/README.md) and [7.1](../../module-07-remote-state/module-07.1-s3-remote-backend-and-locking/README.md), just for Ubuntu (Canonical's owner ID `099720109477`) instead of Amazon Linux.

> 💡 `instance_type = "t3.micro"` — see [8.1](../module-08.1-introduction-to-aws-ec2/README.md#instance-types-cpu-memory-networking) for why I reach for T3 over T2 now.

---

## Key-Based SSH Access

```hcl
resource "aws_key_pair" "web" {
  public_key = file("/root/.ssh/web.pub")
}
```

```hcl
resource "aws_instance" "webserver" {
  # ...
  key_name = aws_key_pair.web.id
}
```

`aws_key_pair` takes an existing **public** key and registers it with AWS — the matching private key (whatever generated that public key locally) is what actually authenticates the SSH session; AWS never sees it and Terraform doesn't need to either, in this version.

> 💡 **An alternative worth knowing:** instead of requiring a public key file to already exist on whatever machine runs `terraform apply`, the `tls_private_key` resource can generate a fresh key pair *inside* Terraform itself:
>
> ```hcl
> resource "tls_private_key" "web" {
>   algorithm = "RSA"
>   rsa_bits  = 4096
> }
>
> resource "aws_key_pair" "web" {
>   public_key = tls_private_key.web.public_key_openssh
> }
> ```
>
> The private key is then available as `tls_private_key.web.private_key_openssh` — mark that output `sensitive = true`, since it's a real credential sitting in state. This is what the [hands-on lab](hands-on-lab/README.md) actually uses, since it doesn't assume any particular file already exists on the machine running it. `file("/root/.ssh/web.pub")` is still the right call when a real, already-managed key pair (a person's own SSH identity) is what should be registered — `tls_private_key` is for a throwaway or lab-generated one.

---

## The Security Group, with Rule Resources Instead of Inline Blocks

```hcl
resource "aws_security_group" "ssh_access" {
  name        = "ssh-access"
  description = "Allow SSH access from the Internet"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.ssh_access.id
  from_port          = 22
  to_port            = 22
  ip_protocol        = "tcp"
  cidr_ipv4          = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.ssh_access.id
  ip_protocol        = "-1"
  cidr_ipv4          = "0.0.0.0/0"
}
```

```hcl
resource "aws_instance" "webserver" {
  # ...
  vpc_security_group_ids = [aws_security_group.ssh_access.id]
}
```

> 💡 Each rule here is its own resource, [`aws_vpc_security_group_ingress_rule`/`aws_vpc_security_group_egress_rule`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule), with its own ID — addable, removable, and taggable independently of the security group itself or any other rule on it. **Don't mix this with inline `ingress`/`egress` blocks on the same security group** — the two styles fighting over the same rule set produces permanent plan diffs.
>
> Also worth being explicit about: an **egress rule isn't optional here** the way it might look. AWS security groups get a default allow-all-outbound rule when created via the console, but a security group built with zero inline `egress` blocks *and* zero separate egress-rule resources has no Terraform-managed outbound rule at all backing that assumption — the `apt update`/`apt install nginx` in `user_data` needs outbound internet access to work, so the explicit `aws_vpc_security_group_egress_rule` above isn't decorative.

---

## Summary

- ✅ Three resources, three jobs: `aws_instance` (the machine), `aws_key_pair` (what can SSH in), `aws_security_group` + rules (what's allowed to reach it)
- ✅ `data "aws_ami"` with `most_recent = true` resolves the current AMI dynamically, in whatever region the provider targets
- ✅ `tls_private_key` generates a key pair inside Terraform itself — no pre-existing local key file required, at the cost of the private key now living in state (mark it `sensitive`)
- ✅ `aws_vpc_security_group_ingress_rule`/`_egress_rule` — one rule, one resource, one ID, managed independently
- ⚠️ An explicit egress rule matters — `user_data`'s `apt install` needs outbound access, and an empty security group provides none by default in Terraform's own management of it

---

## Key Takeaway

**A reachable EC2 instance is the AND of three independent things — a running instance, a registered key, and a security group rule that lets the specific traffic in — and current Terraform practice resolves the AMI dynamically and manages security group rules as their own resources, not inline blocks.**

- ✅ `most_recent = true` + owner ID + name filter = the AMI stays current across every `apply`, forever, with zero manual updates
- ⚠️ Forgetting the egress rule silently breaks `user_data` — the instance still launches, `apt` just can't reach the internet

---

## Practice & Next Steps

Run the [hands-on lab](hands-on-lab/README.md): deploy the instance for real, generate a key pair with `tls_private_key`, SSH in, and confirm nginx is actually running — then confirm it's *not* reachable over HTTP from outside, since the security group only ever opened port 22.

Next up in Module 8: [Terraform Provisioners](../module-08.4-terraform-provisioners/README.md) — running commands *inside* an instance like this one, from Terraform itself.
