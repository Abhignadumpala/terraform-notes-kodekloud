# 📘 Module 8.4: Terraform Provisioners

> [8.3](../module-08.3-aws-ec2-with-terraform/README.md) deployed a webserver with `user_data` doing the actual nginx install. This is the alternative way to run that same install — and, more importantly, why `user_data` was the better choice all along.

---

## What a Provisioner Is, Plain English

A **provisioner** is a block inside a resource that tells Terraform "after (or before) you create/destroy this thing, also run this command." Two flavors: **`remote-exec`** runs a command *on* the resource itself — SSH into the new EC2 instance and run `apt install nginx` there — and **`local-exec`** runs a command on *whatever machine is running `terraform apply`* — write the instance's IP to a local file, ping a Slack webhook, whatever.

**Where they're used:** anywhere a resource's own arguments genuinely can't express what needs to happen — some one-off script, some local bookkeeping, some legacy setup step that has no Terraform-native equivalent.

**Why they exist, and why to be careful with them:** Terraform's whole model is declarative — describe the end state, let Terraform figure out how to get there, and `plan` shows exactly what will change before anything runs. A provisioner breaks that model. It's an imperative escape hatch: "just run this shell command," with none of Terraform's usual guarantees — it doesn't show up meaningfully in `plan`, it doesn't get reliably retried or rolled back the way a resource attribute change does, and if the command fails, `apply` fails with it, by default. HashiCorp's own docs call them "a measure of last resort" for exactly this reason — reach for a resource's own arguments (like `user_data` on an EC2 instance) first, every time, and only fall back to a provisioner when nothing native does the job.

---

## `remote-exec`: Running Commands on the Resource Itself

```hcl
resource "aws_instance" "webserver" {
  ami           = "ami-0edab43b6fa892279"
  instance_type = "t2.micro"

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install nginx -y",
      "sudo systemctl enable nginx",
      "sudo systemctl start nginx",
    ]
  }

  key_name               = aws_key_pair.web.id
  vpc_security_group_ids = [aws_security_group.ssh-access.id]
}
```

Same nginx install as [8.3](../module-08.3-aws-ec2-with-terraform/README.md)'s `user_data`, just run over SSH after the instance exists instead of baked into first boot. Needs the same prerequisites as any SSH session: a security group actually allowing the connection, a key pair, and — since Terraform has to make that SSH connection itself this time — a **connection block** telling it how.

```hcl
resource "aws_instance" "webserver" {
  # ...
  provisioner "remote-exec" {
    inline = [ /* ... */ ]
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file("/root/.ssh/web")
  }
}
```

`self.public_ip` refers to this same resource's own `public_ip` attribute — the instance being provisioned connects to *itself*, once it has an IP to connect to.

---

## `local-exec`: Running Commands Where Terraform Runs

```hcl
resource "aws_instance" "webserver" {
  # ...
  provisioner "local-exec" {
    command = "echo ${aws_instance.webserver.public_ip} >> /tmp/ips.txt"
  }
}
```

No SSH, no connection block — this runs on whatever machine typed `terraform apply`, not on the instance. Useful for local bookkeeping: logging an IP, triggering a local script, updating some file that has nothing to do with AWS.

---

## Create-Time vs. Destroy-Time

Provisioners run at creation by default. Add `when = destroy` to run one right before the resource is torn down instead:

```hcl
resource "aws_instance" "webserver" {
  # ...
  provisioner "local-exec" {
    command = "echo Instance ${aws_instance.webserver.public_ip} Created! > /tmp/instance_state.txt"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "echo Instance ${aws_instance.webserver.public_ip} Destroyed! > /tmp/instance_state.txt"
  }
}
```

Both provisioners reference `aws_instance.webserver.public_ip` — that still resolves at `destroy` time because Terraform reads it from state, not from the (already-gone) real instance.

---

## Handling Failures: `on_failure`

If a provisioner's command fails, `terraform apply` fails with it — the default. A bad path is enough:

```
$ terraform apply
Error: Error running command 'echo 35.183.14.192 > /temp/pub_ip.txt': exit status 1.
Output: The system cannot find the path specified.
```

`on_failure` controls what happens next — it takes exactly two values:

- **`fail`** (the default) — stop, error out. On a *create*-time provisioner, Terraform also **taints** the resource, so the next `apply` destroys and recreates it.
- **`continue`** — log the failure, but let `apply` carry on as if it succeeded.

```hcl
provisioner "local-exec" {
  on_failure = continue
  command    = "echo Instance ${aws_instance.webserver.public_ip} Created! > /temp/instance_state.txt"
}
```

> ⚠️ Worth being precise here, since it's easy to get backwards: `fail` is the *default* — error-and-stop behavior, the same as leaving `on_failure` off entirely. It's `on_failure = continue`, as above, that actually keeps `apply` going despite the failure. Confirmed for real, both ways, in the [hands-on lab](hands-on-lab/README.md).

---

## Best Practice: Prefer Native Resource Capabilities

HashiCorp's own guidance: use a provisioner only when nothing native does the job. AWS's own answer for "run this on first boot" is `user_data` (Azure: custom data; GCP: instance metadata) — no provisioner needed:

```hcl
resource "aws_instance" "webserver" {
  ami           = "ami-0edab43b6fa892279"
  instance_type = "t2.micro"
  tags = {
    Name        = "webserver"
    Description = "An NGINX WebServer on Ubuntu"
  }
  user_data = <<-EOF
    #!/bin/bash
    sudo apt update
    sudo apt install nginx -y
    sudo systemctl enable nginx
    sudo systemctl start nginx
  EOF
}
```

This is exactly [8.3](../module-08.3-aws-ec2-with-terraform/README.md#the-instance-with-a-looked-up-ami-instead-of-a-hardcoded-one)'s approach — the same nginx install, but native to the resource, visible in `plan`, and not dependent on Terraform being able to SSH into the instance at all.

---

## Summary

- ✅ A provisioner runs a command tied to a resource's create or destroy — `remote-exec` on the resource itself (needs a `connection` block), `local-exec` on the machine running Terraform
- ✅ `self.<attribute>` inside a `connection`/`provisioner` block refers to the resource being provisioned
- ✅ `when = destroy` on a provisioner runs it right before the resource is torn down — still-in-state attributes like `public_ip` remain readable at that point
- ⚠️ `on_failure = fail` is the default — a failed provisioner fails the whole `apply` and taints the resource; `on_failure = continue` is what actually keeps going
- ✅ Provisioners are Terraform's escape hatch, not its default tool — `user_data` (or the equivalent on another provider) should be the first thing reached for

---

## Key Takeaway

**A provisioner is what to reach for only after checking the resource's own arguments don't already do it — declarative, visible-in-plan, native configuration beats an imperative shell command tucked inside a resource block every time it's available.**

- ✅ Same end result (`nginx` running) reachable two ways here — `user_data` (8.3) and `remote-exec` (this module) — and the native one is strictly the better choice
- ⚠️ A provisioner failing doesn't just fail quietly — it can taint and force-recreate the resource on the next `apply`, unless `on_failure = continue` says otherwise

---

## Practice & Next Steps

Run the [hands-on lab](hands-on-lab/README.md): a real `remote-exec` + `connection` block installing nginx over SSH, `local-exec` on create and destroy writing to a local file, and a real side-by-side of `on_failure = fail` vs. `on_failure = continue` against a deliberately broken path.

Next up in Module 8: [8.5: Provisioner Behaviour](../module-08.5-provisioner-behaviour/README.md).
