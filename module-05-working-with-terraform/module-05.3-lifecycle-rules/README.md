# 📘 Module 5.3: Lifecycle Rules

> Configuring lifecycle rules in Terraform to manage resource creation and deletion effectively, ensuring service continuity during infrastructure updates

> 🧪 **Hands-on lab:** [Lifecycle Rules](hands-on-lab/README.md) — testing `create_before_destroy`, `prevent_destroy`, and `ignore_changes` against real resources (lab pending — code and screenshots to follow).

---

## Introduction

By default, when Terraform updates a resource, it treats it as **immutable**. This means the existing resource is deleted before a new one is created with the updated configuration. This may not be desirable in all scenarios, especially for production resources where downtime is costly.

Lifecycle rules allow you to control this behavior and prevent unintended disruptions during your infrastructure updates.

---

## Understanding Terraform's Update Mechanism

Consider the following example where we update the SSH key of an EC2 instance:

```hcl
resource "aws_instance" "webserver" {
  ami           = "ami-0edab43b6fa892279"
  instance_type = "t2.micro"
  key_name      = "old-key"  # ← Old SSH key
}
```

When you change the SSH key and run `terraform apply`:

```bash
$ terraform apply
# aws_instance.webserver must be replaced
-/+ resource "aws_instance" "webserver" {
    ami           = "ami-0edab43b6fa892279"
  ~ key_name      = "old-key" -> "new-key"  # forces replacement
    instance_type = "t2.micro"
    id            = "i-0a1b2c3d4e5f6g7h8" -> (known after apply)
}
Plan: 1 to add, 0 to change, 1 to destroy.

aws_instance.webserver: Destroying...
[id=i-0a1b2c3d4e5f6g7h8]
aws_instance.webserver: Destruction complete after 30s
aws_instance.webserver: Creating...
[id=i-0a1b2c3d4e5f6g7h8]

Apply complete! Resources: 1 added, 0 changed, 1 destroyed.
```

**Notice:** Terraform first **destroys** the old instance, then **creates** the new one.

**Problem:** During this 30-60 second process, your website goes DOWN. Users see 502 Bad Gateway. Revenue is lost.

**Solution:** Use lifecycle rules to control this behavior and create the new instance BEFORE destroying the old one (zero downtime!). Terraform offers three of these, all configured within a resource's `lifecycle` block:

---

## The 3 Main Lifecycle Rules

### 1. create_before_destroy

The `create_before_destroy` lifecycle rule instructs Terraform to create a new resource before deleting the old one. This is particularly useful when maintaining service availability is critical. When you update a resource using this rule, Terraform will generate a plan that creates the new resource first and then removes the old one.

**Example - EC2 Instance:**
```hcl
resource "aws_instance" "web" {
  ami           = "ami-0edab43b6fa892279"
  instance_type = "t2.micro"

  lifecycle {
    create_before_destroy = true
  }
}
```

**Why:** When you update the instance, both run briefly. Zero downtime! ✅

---

### 2. prevent_destroy

In some cases, you might want to ensure a resource is never accidentally deleted—even if a configuration change would normally force a replacement. Terraform allows you to achieve this using the `prevent_destroy` rule.

**Example - RDS Database:**
```hcl
resource "aws_db_instance" "prod" {
  identifier     = "prod-database"
  engine         = "mysql"
  instance_class = "db.t3.micro"

  lifecycle {
    prevent_destroy = true
  }
}
```

**What happens:** If you try to delete it, Terraform throws an error. Resource is safe! ✅

⚠️ **Note:** This only blocks config changes. `terraform destroy` will still delete it.

---

### 3. ignore_changes

The `ignore_changes` rule is beneficial when you want Terraform to disregard modifications made to specific attributes. For example, if an external process updates the tags on an AWS EC2 instance, Terraform can be configured to ignore these changes during subsequent runs.

Consider the following AWS EC2 instance configuration:

```hcl
resource "aws_instance" "webserver" {
  ami           = "ami-0edab43b6fa892279"
  instance_type = "t2.micro"
  tags = {
    Name = "ProjectA-Webserver"
  }
}
```

By default, if the tags are updated externally (e.g., changing the tag from "ProjectA-Webserver" to "ProjectB-Webserver"), Terraform will detect the drift and attempt to revert the change:

```bash
$ terraform apply
aws_instance.webserver: Refreshing state... [id=i-05cd83b221911acd5]

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  ~ update in-place

Terraform will perform the following actions:

  # aws_instance.webserver will be updated in-place
  ~ resource "aws_instance" "webserver" {
      ...
      tags = {
          ~ "Name" = "ProjectB-WebServer" -> "ProjectA-WebServer"
      }
      ...
  }

Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

To prevent Terraform from reverting such external changes, add the `ignore_changes` rule to the lifecycle block:

```hcl
resource "aws_instance" "webserver" {
  ami           = "ami-0edab43b6fa892279"
  instance_type = "t2.micro"
  tags = {
    Name = "ProjectA-Webserver"
  }
  lifecycle {
    ignore_changes = [tags]
  }
}
```

Alternatively, to ignore changes across all attributes, you can use the special keyword `all`:

```hcl
resource "aws_instance" "webserver" {
  ami           = "ami-0edab43b6fa892279"
  instance_type = "t2.micro"
  tags = {
    Name = "ProjectA-Webserver"
  }
  lifecycle {
    ignore_changes = all
  }
}
```

After applying these settings, Terraform will refresh the state without making any changes:

```bash
$ terraform apply
aws_instance.webserver: Refreshing state... [id=i-05cd83b221911acd5]
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

**Why:** External tagging system adds tags. Terraform ignores them (doesn't revert). ✅

---

## When to Use Each

✅ **create_before_destroy for:**
- Production websites
- Load-balanced applications
- Any resource where downtime = money loss

✅ **prevent_destroy for:**
- Production databases
- S3 buckets with critical data
- Anything with customer data

✅ **ignore_changes for:**
- Resources managed by other tools
- External tagging systems
- Auto Scaling Group capacity

---

## Lifecycle Rules at a Glance

| Lifecycle Rule | Description | Use Case |
|---|---|---|
| **create_before_destroy** | Creates the new resource before deleting the old one | Ensures continuous availability during updates |
| **prevent_destroy** | Prevents resource destruction during configuration changes | Protects critical resources from accidental deletion |
| **ignore_changes** | Ignores changes to specified attributes or all attributes | Allows external modifications without triggering unwanted changes |

---

## Summary

Three key lifecycle rules in Terraform:

- **The create_before_destroy rule** ensures uninterrupted resource availability by creating the new resource first. This is essential for production environments where downtime is unacceptable.

- **The prevent_destroy rule** safeguards critical resources from unintentional deletion. Use this on databases, backup storage, and any resource containing important data.

- **The ignore_changes rule** allows you to specify attributes that Terraform should ignore during state comparisons, accommodating external changes made by other tools or teams.

**Lifecycle rules are what turn Terraform's destroy-first default into zero-downtime, production-safe deployments!** 🚀
