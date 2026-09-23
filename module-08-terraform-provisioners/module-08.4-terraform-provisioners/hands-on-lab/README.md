# Hands-On Lab: Terraform Provisioners

> Companion hands-on lab for [Module 8.4: Terraform Provisioners](../README.md). Code lives in [`provisioners-code/`](provisioners-code). Two parts: a real EC2 instance with `remote-exec`/`connection`/`local-exec`, and an isolated `null_resource` proving `on_failure = fail` vs. `continue` for real.

---

## What I Built

- **`aws_instance.webserver`** — nginx installed via `remote-exec` over SSH instead of `user_data`, plus `local-exec` on create (logs the public IP locally) and on destroy (logs a "Destroyed" message).
- **`aws_key_pair.web`** — reads a key pair generated with `ssh-keygen` *before* this apply runs, not one Terraform generates as part of it. See the note below on why that's required here, not just a style choice.
- **`null_resource.on_failure_demo`** — a standalone resource, no AWS attached, whose only job is proving `on_failure`'s two values do genuinely different things.

---

## Walking Through It

### 1. Why the key pair can't be `tls_private_key` here

First attempt used `tls_private_key` + `aws_key_pair`, exactly like [8.3](../../module-08.3-aws-ec2-with-terraform/hands-on-lab/README.md). `terraform init`/`plan` refused it:

```
Error: Invalid function argument

Destroy-time provisioners and their connection configurations may only
reference attributes of the related resource, via 'self', 'count.index', or
'each.key'.
```

The `connection` block is shared by every provisioner on a resource — including the destroy-time `local-exec` below it — and a destroy-time provisioner's connection is restricted to `self`-only references. `tls_private_key.web.private_key_openssh` is a different resource's attribute, so it's rejected, even though the *destroy-time* provisioner here doesn't even use SSH.

Switching to `file("${path.module}/web.pem")` (reading a key some other resource in this same config would create) hit a second, different error:

```
Error: Invalid function argument
Invalid value for "path" parameter: no file exists at "./web.pem"; this
function works only with files that are distributed as part of the
configuration source code
```

`file()` reads from disk at plan time — it can't read a file some other resource in the *same* apply hasn't created yet. Put together, these two errors are exactly why a pre-existing key, generated **outside** Terraform before `apply` ever runs, is the way around both restrictions at once. Generated one for real:

```bash
ssh-keygen -t rsa -b 4096 -f ./web -N "" -C "module-08-4-provisioners"
```

### 2. Apply — `remote-exec` really running over SSH

```bash
terraform apply
```

```
aws_instance.webserver (remote-exec): Scanning processes...
aws_instance.webserver (remote-exec): Synchronizing state of nginx.service with SysV service script...
aws_instance.webserver: Still creating... [00m50s elapsed]
aws_instance.webserver: Provisioning with 'local-exec'...
aws_instance.webserver (local-exec): Executing: ["/bin/sh" "-c" "echo Instance 13.219.207.120 Created! > ./instance_state.txt"]
aws_instance.webserver: Creation complete after 51s [id=i-0dbf1ccaf6048d6bc]

Apply complete! Resources: 5 added, 0 changed, 0 destroyed.
```

That `(remote-exec)`-prefixed output is Terraform's own SSH session, live — not a plan preview, the actual `apt update`/`apt install nginx` running on the instance.

### 3. Confirm both provisioners actually did their job

Create-time `local-exec`:

```bash
cat instance_state.txt
```
```
Instance 13.219.207.120 Created!
```

`remote-exec`, confirmed independently over a fresh SSH session (not trusting the provisioner's own "it didn't error" as proof):

```bash
ssh -i web ubuntu@13.219.207.120 "systemctl is-active nginx; systemctl is-enabled nginx"
```
```
active
enabled
```

### 4. Destroy — the destroy-time provisioner, live

```bash
terraform destroy
```

```
aws_instance.webserver: Destroying... [id=i-0dbf1ccaf6048d6bc]
aws_instance.webserver: Provisioning with 'local-exec'...
aws_instance.webserver (local-exec): Executing: ["/bin/sh" "-c" "echo Instance 13.219.207.120 Destroyed! > ./instance_state.txt"]
aws_instance.webserver: Destruction complete after 31s

Destroy complete! Resources: 5 destroyed.
```

```bash
cat instance_state.txt
```
```
Instance 13.219.207.120 Destroyed!
```

The destroy-time provisioner ran **before** the instance was actually torn down (it's the first line after "Destroying...") — `self.public_ip` still resolved correctly, read from state rather than the (by-then-vanishing) real instance.

### 5. `on_failure = fail` (the default), for real

`null_resource.on_failure_demo`, first applied with no `on_failure` set at all — the default:

```bash
terraform apply -target=null_resource.on_failure_demo
```

```
null_resource.on_failure_demo (local-exec): Executing: ["/bin/sh" "-c" "echo this fails on purpose > /no/such/directory/state.txt"]
null_resource.on_failure_demo (local-exec): /bin/sh: 1: cannot create /no/such/directory/state.txt: Directory nonexistent

Error: local-exec provisioner error
Error running command 'echo this fails on purpose > /no/such/directory/state.txt': exit status 2.
```

`apply` exited non-zero. The second provisioner (the one that would've written `on_failure_state.txt`) never ran — confirmed, the file doesn't exist. And the resource itself:

```bash
terraform show
```
```
# null_resource.on_failure_demo: (tainted)
```

**Tainted**, exactly as documented — the next `apply` destroys and recreates it rather than treating it as already-created.

### 6. `on_failure = continue`, same failing command, real side-by-side

Added `on_failure = continue` to the first provisioner, re-applied:

```bash
terraform apply -target=null_resource.on_failure_demo
```

```
-/+ resource "null_resource" "on_failure_demo" {
      ~ id = "7362178295993191125" -> (known after apply)
    }
# null_resource.on_failure_demo is tainted, so must be replaced

null_resource.on_failure_demo (local-exec): Executing: ["/bin/sh" "-c" "echo this fails on purpose > /no/such/directory/state.txt"]
null_resource.on_failure_demo (local-exec): /bin/sh: 1: cannot create /no/such/directory/state.txt: Directory nonexistent
null_resource.on_failure_demo: Provisioning with 'local-exec'...
null_resource.on_failure_demo (local-exec): Executing: ["/bin/sh" "-c" "echo second provisioner ran anyway, on_failure = continue worked > ./on_failure_state.txt"]
null_resource.on_failure_demo: Creation complete after 0s

Apply complete! Resources: 1 added, 0 changed, 1 destroyed.
```

Same exact broken command, same exact error printed — but this time `apply` exited `0`, and the second provisioner ran:

```bash
cat on_failure_state.txt
```
```
second provisioner ran anyway, on_failure = continue worked
```

Also confirmed the tainted-resource replacement itself, as a side effect: the previous run's taint is exactly what triggered the `-/+ destroy and then create replacement` at the top of this apply.

### Clean up

```bash
terraform destroy -auto-approve
rm -f instance_state.txt on_failure_state.txt web web.pub
```

---

## Summary

- **`remote-exec` confirmed live**, not just by absence of an error — a follow-up SSH session independently confirmed `nginx active`/`enabled`.
- **Destroy-time provisioner confirmed live** — `instance_state.txt`'s content genuinely changed from `Created!` to `Destroyed!`, and it ran before the instance actually disappeared.
- **The key pair had to be pre-generated with `ssh-keygen`**, not `tls_private_key` — a destroy-time provisioner on the same resource forces the shared `connection` block into `self`-only references, and `file()` can't read a file this same apply hasn't created yet by the time it plans.
- **`on_failure` confirmed both ways, same broken command**: `fail` (default) halts `apply` and taints the resource; `continue` logs the same error but lets the rest of the resource's provisioners run, and `apply` exits clean.

**Next up:** [8.5: Provisioner Behaviour](../../module-08.5-provisioner-behaviour/README.md).
