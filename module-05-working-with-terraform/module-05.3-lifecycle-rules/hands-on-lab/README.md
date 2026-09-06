# Hands-On Lab: Lifecycle Rules

> Companion hands-on lab for [Module 5.3: Lifecycle Rules](../README.md). Code lives in [`lifecycle-rules-code/`](lifecycle-rules-code) — this is what you actually run locally (`cd` into that folder and use standard `terraform init`/`plan`/`apply`).

---

## What I Built

One EC2 instance and one S3 bucket, in the same config, each set up to demonstrate a different rule:

- **`aws_instance.web`** (`ec2_instance.tf`) — `create_before_destroy = true` and `ignore_changes = [tags]` together, so I can test both rules against the same instance without spinning up extra resources.
- **`aws_s3_bucket.protected`** (`protected_bucket.tf`) — `prevent_destroy = true`, to test that Terraform actually refuses to remove it.

Files: `provider.tf`, `ec2_instance.tf`, `protected_bucket.tf`, `outputs.tf`.

---

## Walking Through It (to run)

### 1. Deploy the baseline

```bash
cd lifecycle-rules-code
terraform init
terraform apply
```

This creates the instance (on the Amazon Linux AMI) and the bucket.

### 2. Test `create_before_destroy`

Edit `ec2_instance.tf` — change the instance's `ami` from `data.aws_ami.amazon_linux.id` to `data.aws_ami.ubuntu.id`. Then:

```bash
terraform plan
```

Look for `+/-` in the plan (create first) instead of the default `-/+` (destroy first). Run `terraform apply` and watch — the new instance should come up before the old one is torn down.

### 3. Test `ignore_changes`

Change the instance's `Name` tag from outside Terraform — the AWS console, or:

```bash
aws ec2 create-tags --resources <instance-id> --tags Key=Name,Value=changed-externally
```

Then run `terraform plan`. It should come back clean (`No changes`) instead of trying to revert the tag back to `lifecycle-rules-lab`.

### 4. Test `prevent_destroy`

```bash
terraform destroy
```

Expect this to fail specifically on `aws_s3_bucket.protected` with an error about `prevent_destroy` — everything else (the instance) should still be eligible for destruction.

### 5. Clean up

`prevent_destroy` blocks `terraform destroy` too, not just config changes that would replace the resource — so to actually remove the bucket:

1. Delete (or comment out) the `lifecycle { prevent_destroy = true }` block in `protected_bucket.tf`.
2. Run `terraform apply` to update the resource in state with the new lifecycle config.
3. Run `terraform destroy` again — it should go through cleanly this time.

---

## What This Confirms

*Pending — will fill in with real plan/apply output and screenshots once I run through the steps above.*
