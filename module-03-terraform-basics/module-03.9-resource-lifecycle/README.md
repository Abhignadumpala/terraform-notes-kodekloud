# 3.9: Resource Lifecycle in Terraform

> This lesson explores the `lifecycle` meta-argument in Terraform, covering how to control resource creation order, prevent accidental destruction, and ignore specific attribute changes during updates.

---

## What is the Lifecycle Meta-Argument?

Every Terraform resource goes through a basic lifecycle by default: **create**, **update (in-place or replace)**, and **destroy**, driven entirely by whatever `terraform plan` decides needs to change to match my configuration.

Sometimes I need more control than the defaults give me — for example, I don't want an old resource destroyed before its replacement exists, or I want to protect a resource from ever being destroyed by accident. That's what the `lifecycle` block (a **meta-argument** — it can be added to any resource, regardless of provider) is for.

```hcl
resource "aws_instance" "example" {
  # ...resource config...

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = false
    ignore_changes        = []
  }
}
```

---

## Table of Contents
1. [create_before_destroy](#create_before_destroy)
2. [prevent_destroy](#prevent_destroy)
3. [ignore_changes](#ignore_changes)
4. [Real-World AWS Examples](#real-world-aws-examples)
5. [Lifecycle Best Practices](#lifecycle-best-practices)

---

## create_before_destroy

### What it does

By default, when a resource needs to be replaced (a change that can't be done in-place, like changing an AMI ID on an EC2 instance), Terraform's default order is:

1. Destroy the old resource
2. Create the new resource

`create_before_destroy = true` flips that order:

1. Create the new resource
2. Destroy the old resource, only once the new one exists

### Why I'd want this

Without it, there's a window where the resource doesn't exist at all — for something like a load-balanced web server, that's downtime. With `create_before_destroy`, the new instance comes up first, so there's overlap instead of a gap.

### Example

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t2.micro"

  lifecycle {
    create_before_destroy = true
  }
}
```

**Gotcha:** if the resource has a `name` (or other) attribute that must be unique, the new and old resources briefly exist at the same time — so a hardcoded unique name will conflict. I need to make the name computed (e.g. include `random_pet` or a timestamp) when using this.

---

## prevent_destroy

### What it does

Setting `prevent_destroy = true` tells Terraform to reject any plan that would destroy this resource — including `terraform destroy` and a `terraform apply` that would replace it. Terraform errors out instead of proceeding.

### Why I'd want this

For anything critical and hard to recreate — a production database, an S3 bucket holding important state or data — this is a safety net against a `terraform destroy` or a careless config change accidentally wiping it out.

### Example

```hcl
resource "aws_db_instance" "prod" {
  identifier        = "prod-db"
  engine            = "mysql"
  instance_class    = "db.t3.medium"
  allocated_storage = 20

  lifecycle {
    prevent_destroy = true
  }
}
```

**Gotcha:** this only protects against Terraform-initiated destruction. It doesn't stop someone from deleting the resource manually in the AWS Console — Terraform would just see drift on the next plan. To actually remove a protected resource, I have to first set `prevent_destroy = false` (or delete the lifecycle block) and apply that change before destroying.

---

## ignore_changes

### What it does

Tells Terraform to ignore changes to specific attributes when comparing the real infrastructure to my config — so `terraform plan` won't propose an update for those fields, even if they've drifted.

### Why I'd want this

Common case: some other process (autoscaling, a teammate, a separate tool) modifies an attribute outside of Terraform — like `desired_capacity` on an autoscaling group being changed by a scaling policy, or `tags` being added by an org-wide tagging Lambda. Without `ignore_changes`, Terraform would try to "fix" that drift back to my config's value on every apply.

### Example

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t2.micro"

  tags = {
    Name = "web-server"
  }

  lifecycle {
    ignore_changes = [tags]
  }
}
```

I can also target specific nested keys (`tags["Environment"]`) instead of the whole attribute, or pass `all` to ignore every attribute after initial creation (rare — usually too broad).

---

## Real-World AWS Examples

### Zero-downtime instance replacement

```hcl
resource "aws_launch_template" "app" {
  name_prefix   = "app-"
  image_id      = var.ami_id
  instance_type = "t3.micro"

  lifecycle {
    create_before_destroy = true
  }
}
```

### Protecting a Terraform state backend bucket

```hcl
resource "aws_s3_bucket" "tf_state" {
  bucket = "my-terraform-state-bucket"

  lifecycle {
    prevent_destroy = true
  }
}
```

### Autoscaling group with externally-managed capacity

```hcl
resource "aws_autoscaling_group" "app" {
  desired_capacity = 2
  min_size         = 1
  max_size         = 5

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}
```

---

## Lifecycle Best Practices

- Use `prevent_destroy` on anything genuinely hard/impossible to recreate (databases, state buckets) — not on everything, or it becomes noise.
- Pair `create_before_destroy` with resource names/identifiers that won't collide (avoid hardcoded unique names).
- Keep `ignore_changes` narrow — list the specific attributes that drift, rather than reaching for `all`, so real config drift elsewhere still gets caught.
- Remember `lifecycle` arguments must be literal values — I can't use variables or expressions inside a `lifecycle` block.

---

[Back to Module 03 overview](../)
