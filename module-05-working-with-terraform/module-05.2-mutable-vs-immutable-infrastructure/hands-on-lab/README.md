# Hands-On Lab: Mutable vs Immutable Infrastructure

> Companion hands-on lab for [Module 5.2: Mutable vs Immutable Infrastructure](../README.md). Code lives in [`mutable-vs-immutable-code/`](mutable-vs-immutable-code).

---

## What I'm Testing

One EC2 instance, two different kinds of changes, to see the theory from the module notes actually happen on AWS:

1. Change a **tag** → this should be a mutable, in-place update (`~` in the plan, same instance ID).
2. Change the **instance type** → this should be immutable, destroy-and-recreate (`-/+` in the plan, brand new instance ID).

The point isn't the EC2 instance itself, it's watching Terraform pick a different strategy depending on which attribute changed.

Files: `provider.tf`, `ec2_instance.tf`, `outputs.tf`. Free-tier eligible (`t2.micro` / `t2.small`).

---

## Walking Through It

### 1. Deploy the baseline

```bash
cd mutable-vs-immutable-code
terraform init
terraform plan
terraform apply -auto-approve
```

This creates the instance with `instance_type = "t2.micro"` and tag `Name = "web-server-v1"`. I'll note the `instance_id` from the output — I'm going to compare it against itself after each change.

### 2. Part 1 — mutable change (tag)

In `ec2_instance.tf`, change the tag:

```hcl
Name = "web-server-v1"   # ->
Name = "web-server-v2"
```

```bash
terraform plan
```

Expect a `~` (update in-place) on `aws_instance.web_server`, not a `-/+`. The `id` in the plan should stay the same value I noted in step 1.

```bash
terraform apply -auto-approve
```

Apply summary should read `0 added, 1 changed, 0 destroyed`. Same instance, no downtime — the tag just moved.

### 3. Part 2 — immutable change (instance type)

In `ec2_instance.tf`, change the instance type:

```hcl
instance_type = "t2.micro"   # ->
instance_type = "t2.small"
```

```bash
terraform plan
```

This time expect `-/+` — "must be replaced" — with `instance_type` marked `# forces replacement` and `id` shown as `(known after apply)`.

```bash
terraform apply -auto-approve
```

Apply summary should read `1 added, 0 changed, 1 destroyed`. New `instance_id` and new `instance_public_ip` in the output — a genuinely different instance, not the one from step 1.

### 4. Clean up

```bash
terraform destroy -auto-approve
```

---

## What This Confirms

| | Tag change (Part 1) | Instance type change (Part 2) |
|---|---|---|
| Plan symbol | `~` | `-/+` |
| Instance ID | same | different |
| Action | Modify | Destroy & Create |
| Downtime | none | yes, unless I add `create_before_destroy` |

Matches what [Module 5.2](../README.md) says: Terraform isn't purely mutable or purely immutable — it picks per-attribute, based on whether the provider says that attribute can be updated in place or forces a replacement.

**Optional follow-up:** add `lifecycle { create_before_destroy = true }` to the resource, re-run the instance-type change, and watch the plan create the new instance *before* destroying the old one instead of after.
