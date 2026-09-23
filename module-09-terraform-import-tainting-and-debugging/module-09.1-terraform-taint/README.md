# 📘 Module 9.1: Terraform Taint

> In [8.4](../../module-08-terraform-provisioners/module-08.4-terraform-provisioners/README.md#handling-failures-on_failure) I saw that a failed create-time provisioner leaves the resource **tainted**. This note is about what "tainted" actually means, how to clear it, and how I force Terraform to rebuild a resource on purpose.

---

## What "Tainted" Means, Plain English

Think of a tainted resource like a dish the kitchen made but isn't sure is right. It's on the table (it exists), but the kitchen has marked it "don't trust this one." Next time I order, the kitchen throws it away and makes a fresh one.

In Terraform terms: a **tainted** resource is one that exists for real and is in the state file, but Terraform has marked it as "not trustworthy." On the next `terraform apply`, Terraform **destroys it and creates a new one** — even if nothing in my code changed.

The mark lives only in the state file. Tainting doesn't touch the real server at all.

---

## How a Resource Gets Tainted on Its Own

The most common way: a create-time provisioner fails. Here the `local-exec` writes to `/temp`, a folder that doesn't exist:

```hcl
resource "aws_instance" "webserver" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  tags = {
    Name        = "webserver"
    Description = "An NGINX WebServer on Ubuntu"
  }

  provisioner "local-exec" {
    command = "echo ${self.public_ip} > /temp/pub_ip.txt"
  }
}
```

The instance itself gets created fine. Then the provisioner fails, and `apply` errors out:

```
Error running command 'echo ... > /temp/pub_ip.txt': exit status 2. Output:
/bin/sh: 1: cannot create /temp/pub_ip.txt: Directory nonexistent
```

Terraform can't tell if the instance is set up correctly, so it marks it tainted. `terraform show` confirms it:

```
# aws_instance.webserver: (tainted)
```

And the next `plan` wants to replace it:

```
  # aws_instance.webserver is tainted, so must be replaced
-/+ resource "aws_instance" "webserver" {
Plan: 1 to add, 0 to change, 1 to destroy.
```

> 💡 I tested every command in this note for real with a local `terraform_data` resource (free, no AWS needed) using the same broken `/temp` path. The error, `(tainted)` marker, and plan lines above are what I saw.

---

## Forcing a Replacement on Purpose: `-replace`

Sometimes the resource is "fine" as far as Terraform knows, but I *want* a fresh one — for example, someone changed things by hand inside the server, or it's acting strangely.

I add the `-replace` option to `plan` or `apply`:

```bash
terraform plan -replace="aws_instance.webserver"
```

```
  # aws_instance.webserver will be replaced, as requested
-/+ resource "aws_instance" "webserver" {
Plan: 1 to add, 0 to change, 1 to destroy.
```

```bash
terraform apply -replace="aws_instance.webserver"
```

This is the way I force a rebuild. The big plus: the replacement shows up in the plan **before** anything happens. I review it, then say yes. Nothing is marked in the state file ahead of time, so a teammate running `plan` at the same moment isn't surprised by it.

For a resource with `count` or `for_each`, I include the index or key in quotes:

```bash
terraform apply -replace='aws_instance.webserver[0]'
```

Official docs: [`terraform plan -replace`](https://developer.hashicorp.com/terraform/cli/commands/plan#replace-address).

---

## `terraform taint` — The Deprecated Way

`terraform taint` marks a resource as tainted directly in the state file:

```bash
terraform taint aws_instance.webserver
```

```
Resource instance aws_instance.webserver has been marked as tainted.
```

The next `apply` then replaces it. It still works, but it's **deprecated** — HashiCorp's own docs recommend `apply -replace` instead. The problem with `taint`: it changes the state file *straight away*, before I've seen any plan. Anyone else working on the same state picks up the "replace me" mark without knowing why.

Official docs: [`terraform taint`](https://developer.hashicorp.com/terraform/cli/commands/taint).

---

## Clearing the Mark: `terraform untaint`

If a resource got tainted but I've checked it and it's actually fine, I remove the mark so Terraform won't rebuild it:

```bash
terraform untaint aws_instance.webserver
```

```
Resource instance aws_instance.webserver has been successfully untainted.
```

```bash
terraform plan
```

```
No changes. Your infrastructure matches the configuration.
```

`untaint` only changes the state file. It doesn't touch the real server, and it isn't deprecated.

Official docs: [`terraform untaint`](https://developer.hashicorp.com/terraform/cli/commands/untaint).

---

## Summary

- ✅ A tainted resource exists for real, but Terraform will destroy and recreate it on the next `apply`
- ✅ A failed create-time provisioner taints its resource automatically
- ✅ `terraform apply -replace="ADDRESS"` forces a rebuild, and it shows up in the plan first
- ⚠️ `terraform taint` still works but is deprecated — it changes state before any plan is shown
- ✅ `terraform untaint` removes the mark when I've checked the resource is actually fine
- ✅ Taint and untaint only change the state file, never the real resource

---

## Key Takeaway

**To rebuild a resource, I use `terraform apply -replace="ADDRESS"`. To keep a tainted resource that's actually fine, I use `terraform untaint`.**

- ✅ `-replace` is reviewed in the plan like any other change
- ⚠️ A tainted resource gets destroyed on the next `apply`, so I check `terraform show` for `(tainted)` before applying after a failed run

---

## Practice & Next Steps

Take [8.4](../../module-08-terraform-provisioners/module-08.4-terraform-provisioners/README.md)'s webserver, break its `local-exec` path on purpose, and run `apply` → `terraform show` → `untaint` → `plan` → `apply -replace` to see each step.

Next up: [9.2: Debugging](../module-09.2-debugging/README.md).
