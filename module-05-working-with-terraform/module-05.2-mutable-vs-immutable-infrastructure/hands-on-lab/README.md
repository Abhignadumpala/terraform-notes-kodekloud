# Hands-On Lab: Mutable vs Immutable Infrastructure

> Companion hands-on lab for [Module 5.2: Mutable vs Immutable Infrastructure](../README.md). Code lives in [`mutable-vs-immutable-code/`](mutable-vs-immutable-code).

---

## What I'm Testing

One EC2 instance, two different kinds of changes, to see the theory from the module notes actually happen on AWS:

1. Change a **tag** → mutable, in-place update (`~` in the plan, same instance ID).
2. Change the **AMI** → immutable, destroy-and-recreate (`-/+` in the plan, brand new instance ID).

**Why AMI and not instance type:** my first pass at this lab used `instance_type` (`t2.micro` → `t2.small`) as the "immutable" example. Wrong — `instance_type` is *not* a ForceNew attribute on `aws_instance`. Terraform just stops the instance, calls `ModifyInstanceAttribute`, and starts it back up with the same instance ID. I confirmed this myself running it against `t2.small` and even `m1.small` — same instance, every time. `ami`, on the other hand, actually is ForceNew, so swapping it is the real destroy-and-recreate case.

The point isn't the EC2 instance itself, it's watching Terraform pick a different strategy per-attribute, not per-resource.

Files: `provider.tf`, `ec2_instance.tf`, `outputs.tf`. Free-tier eligible (`t2.micro`).

---

## Walking Through It

### 1. Deploy the baseline

```bash
cd mutable-vs-immutable-code
terraform init
terraform plan
terraform apply -auto-approve
```

This creates the instance from the `amazon_linux` AMI with tag `Name = "web-server-v1"`. I'll note the `instance_id` and `current_ami` from the output — comparing those against themselves is the whole test.

### 2. Part 1 — mutable change (tag)

In `ec2_instance.tf`, change the tag:

```hcl
Name = "web-server-v1"   # ->
Name = "web-server-v2"
```

```bash
terraform plan
```

Expect a `~` (update in-place) on `aws_instance.web_server`, not a `-/+`. The `id` in the plan stays the same value I noted in step 1.

```bash
terraform apply -auto-approve
```

Apply summary should read `0 added, 1 changed, 0 destroyed`. Same instance, no downtime — only the tag moved.

### 3. Part 2 — immutable change (AMI)

In `ec2_instance.tf`, point the instance at the Ubuntu AMI instead:

```hcl
ami = data.aws_ami.amazon_linux.id   # ->
ami = data.aws_ami.ubuntu.id
```

```bash
terraform plan
```

This time expect `-/+` — "must be replaced" — with `ami` marked `# forces replacement` and `id` shown as `(known after apply)`.

```bash
terraform apply -auto-approve
```

Apply summary should read `1 added, 0 changed, 1 destroyed`. New `instance_id`, new `current_ami`, new `instance_public_ip` — a genuinely different instance, not the one from step 1.

### 4. Clean up

```bash
terraform destroy -auto-approve
```

---

## What This Confirms

| | Tag change (Part 1) | AMI change (Part 2) |
|---|---|---|
| Plan symbol | `~` | `-/+` |
| Instance ID | same | different |
| Action | Modify | Destroy & Create |
| Downtime | none | yes, unless I add `create_before_destroy` |

Matches what [Module 5.2](../README.md) says: Terraform isn't purely mutable or purely immutable — it picks per-attribute, based on whether the provider marks that attribute as ForceNew. Tags aren't ForceNew. `ami` is. `instance_type` isn't (a common assumption I got wrong the first time around).

**Optional follow-up:** add `lifecycle { create_before_destroy = true }` to the resource, re-run the AMI change, and watch the plan create the new instance *before* destroying the old one instead of after.
