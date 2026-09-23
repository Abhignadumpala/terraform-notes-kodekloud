# 📘 Module 9.1: Terraform Taint

> In this note, I explain how to use Terraform's taint and untaint commands to manage resource recreation. These commands are useful when a resource fails during creation or when manual changes happen that need a fresh deployment.

---

## Overview

Terraform marks a resource as tainted when it hits errors during creation, such as a failed provisioner command. A tainted resource is scheduled for replacement during the next apply. The untaint command clears this status and prevents the replacement.

> 💡 Using taint and untaint lets me control a resource's lifecycle without a complete destroy and reapply cycle.

---

## Scenario: Tainted Resource due to Provisioner Failure

Say I provision an AWS EC2 instance with a local provisioner that stores its public IP address in a file. If the provisioner command fails — for example, because the file path is wrong — the resource is marked as tainted, and it gets replaced on the next apply.

### Resource Definition Example

```hcl
resource "aws_instance" "webserver" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = "ws"

  provisioner "local-exec" {
    command = "echo ${self.public_ip} > /temp/pub_ip.txt"
  }
}
```

`self.public_ip` means "this same instance's public IP." Terraform's docs say to use `self` when a provisioner refers to its own resource.

### Applying the Configuration

When I run apply, the output shows the provisioner failing:

```bash
$ terraform apply
Plan: 1 to add, 0 to change, 0 to destroy.

aws_instance.webserver: Creating...
aws_instance.webserver: Still creating... [10s elapsed]
aws_instance.webserver: Still creating... [20s elapsed]
aws_instance.webserver: Still creating... [30s elapsed]
aws_instance.webserver: Provisioning with 'local-exec'...
aws_instance.webserver (local-exec): Executing: ["cmd" "/C" "echo 35.183.14.192 > /temp/pub_ip.txt"]
aws_instance.webserver (local-exec): The system cannot find the path specified.

Error: Error running command 'echo 35.183.14.192 > /temp/pub_ip.txt': exit status 1. Output: The system
```

At this point, Terraform marks the "webserver" resource as tainted.

### Verifying the Tainted Resource

Running `terraform plan` confirms that the tainted resource is scheduled for replacement:

```bash
$ terraform plan
aws_instance.webserver: Refreshing state... [id=i-0dba2d5dc22a9a904]

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
-/+ destroy and then create replacement

Terraform will perform the following actions:

  # aws_instance.webserver is tainted, so must be replaced
-/+ resource "aws_instance" "webserver" {
```

> ⚠️ Double-check the resource configuration and provisioner commands to avoid replacing a resource by accident.

---

## Forcing a Resource Rebuild

Sometimes I want to rebuild a resource on purpose. For example, if manual changes — like updating the Nginx version — were made on an AWS instance, I can trigger a fresh copy of just that resource without a full destroy and apply cycle.

### Replacing the Resource

The recommended way is the `-replace` option:

```bash
$ terraform apply -replace="aws_instance.webserver"
```

The plan shows the replacement first, and nothing changes until I confirm:

```bash
  # aws_instance.webserver will be replaced, as requested
-/+ resource "aws_instance" "webserver" {
```

### Tainting the Resource

The `terraform taint` command also marks a resource for replacement:

```bash
$ terraform taint aws_instance.webserver
Resource instance aws_instance.webserver has been marked as tainted.
```

> ⚠️ `terraform taint` is deprecated. It changes the state file straight away, before any plan is shown. `terraform apply -replace` does the same job but shows the change in the plan first, so I use that one. Official docs: [`terraform taint`](https://developer.hashicorp.com/terraform/cli/commands/taint).

### Confirming the Change with Terraform Plan

After tainting, `terraform plan` shows that the resource is scheduled for replacement:

```bash
$ terraform plan
aws_instance.webserver: Refreshing state... [id=i-0fd3946f5b3ab8af8]

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
-/+ destroy and then create replacement

Terraform will perform the following actions:

  # aws_instance.webserver is tainted, so must be replaced
-/+ resource "aws_instance" "webserver" {
```

---

## Reversing Taint: Using the Untaint Command

If I decide later that a resource should not be replaced, I remove its tainted state with the untaint command. This stops Terraform from destroying and recreating the resource on the next apply.

```bash
$ terraform untaint aws_instance.webserver
Resource instance aws_instance.webserver has been successfully untainted.
```

Official docs: [`terraform untaint`](https://developer.hashicorp.com/terraform/cli/commands/untaint).

---

## Summary Table

| Command | Action | Description |
|---------|--------|-------------|
| `terraform apply -replace="ADDRESS"` | Replace a resource | Forces the resource to be replaced, shown in the plan first |
| `terraform taint` | Mark resource as tainted (deprecated) | Forces the resource to be replaced on the next apply |
| `terraform untaint` | Remove taint from resource | Prevents resource replacement during the next apply |
| `terraform plan` | Verify resource replacement plan | Confirms which resources are marked for replacement |
| `terraform apply` | Apply configuration changes | Executes resource creation and replacement operations |

---

## Summary

- ✅ A failed provisioner during creation marks the resource as tainted
- ✅ A tainted resource is destroyed and recreated on the next apply
- ✅ `terraform apply -replace` forces a rebuild and shows it in the plan first
- ⚠️ `terraform taint` still works but is deprecated
- ✅ `terraform untaint` removes the taint so the resource is not replaced

---

## Key Takeaway

**To rebuild a resource, I use `terraform apply -replace`. To keep a tainted resource, I use `terraform untaint`.**

- ✅ `terraform plan` always shows `tainted, so must be replaced` or `will be replaced, as requested` before anything happens
- ⚠️ Taint and untaint only change the state file — the real server is untouched until the next apply

---

## Practice & Next Steps

Take [8.4](../../module-08-terraform-provisioners/module-08.4-terraform-provisioners/README.md)'s webserver, break its `local-exec` path on purpose, and run `apply` → `plan` → `untaint` → `apply -replace` to see each step.

Next up: [9.2: Debugging](../module-09.2-debugging/README.md).
