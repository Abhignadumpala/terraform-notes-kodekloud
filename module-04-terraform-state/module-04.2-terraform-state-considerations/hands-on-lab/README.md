# Hands-On Lab: S3 Backend + Native State Locking

> Companion hands-on lab for [Module 04.2: Terraform State Considerations](../README.md#securing-state-in-s3) — see that note for the full explanation of how remote state and S3 native locking actually work. Code lives in [`bootstrap/`](bootstrap) and [`app/`](app).

## Table of Contents

1. [What I Built](#what-i-built)
2. [Walking Through It](#walking-through-it)
   1. [Create the backend resources](#1-create-the-backend-resources)
   2. [Point `app/` at that bucket](#2-point-app-at-that-bucket)
   3. [Initialize `app/` against the S3 backend](#3-initialize-app-against-the-s3-backend)
   4. [Apply and confirm state actually moved](#4-apply-and-confirm-state-actually-moved)
   5. [Simulate a held lock](#5-simulate-a-held-lock)
   6. [Resolve the lock](#6-resolve-the-lock)
   7. [Clean up](#7-clean-up)
3. [What This Confirms](#what-this-confirms)

---

## What I Built

- **`bootstrap/`** — creates the S3 bucket. Stays on local state, since it's creating the very backend other configs will point at.
- **`app/`** — one free-tier EC2 instance, using the bucket from `bootstrap/` as its `backend "s3"`, with `use_lockfile = true` for locking (no DynamoDB table).

*Redoing this lab against native S3 locking (it was originally built on DynamoDB) — screenshots to follow once it's rerun.*

---

## Walking Through It

### 1. Create the backend resources

```bash
cd bootstrap
terraform init
terraform apply
```

```
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

Outputs:
state_bucket_name = "tf-state-mutable-immutable-lab-47393c8b"
```

### 2. Point `app/` at that bucket

Typed the real bucket name into `app/provider.tf`'s backend block by hand — Terraform reads this block before anything else runs, so it can't pull the value from a variable or another config's output. It has to be plain text:

```hcl
backend "s3" {
  bucket       = "tf-state-mutable-immutable-lab-47393c8b"
  key          = "state-locking-lab/terraform.tfstate"
  region       = "us-east-1"
  use_lockfile = true
  encrypt      = true
}
```

### 3. Initialize `app/` against the S3 backend

```bash
cd ../app
terraform init
```

```
Successfully configured the backend "s3"! Terraform will automatically
use this backend unless the backend configuration changes.
```

### 4. Apply and confirm state actually moved

```bash
terraform plan
terraform apply
```

```
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

`ls` in `app/` shows only `.tf` files — no local `terraform.tfstate` anymore. In S3, the state file itself showed up at `state-locking-lab/terraform.tfstate`, and a lock file briefly appeared right next to it while the apply was running.

### 5. Simulate a held lock

```bash
aws s3api put-object \
  --bucket tf-state-mutable-immutable-lab-47393c8b \
  --key state-locking-lab/terraform.tfstate.tflock \
  --body fake-lock.json

terraform plan
```

```
Error: Error acquiring the state lock

Lock Info:
  ID:        fake-lock-id
  Operation: OperationTypeApply
  Who:       someone-else@another-machine

Terraform acquires a state lock to protect the state from being written
by multiple users at the same time. Please resolve the issue above and
try again.
```

### 6. Resolve the lock

```bash
terraform force-unlock fake-lock-id
```

```
Terraform state has been successfully unlocked!
```

`terraform plan` right after came back clean — no changes.

### 7. Clean up

```bash
cd app && terraform destroy
cd ../bootstrap && terraform destroy
```

```
Destroy complete! Resources: 1 destroyed.
...
Destroy complete! Resources: 5 destroyed.
```

---

## What This Confirms

| | Local state (default) | S3 + native locking (this lab) |
|---|---|---|
| Where state lives | `terraform.tfstate` on disk | The same file, but in S3 (confirmed) |
| Visible to teammates/CI | No | Yes |
| Concurrent `apply` protection | None | The S3 lock file blocked `plan` outright |
| Extra AWS resources for locking | N/A | None |
| Lost-laptop risk | State gone with it | State untouched |

Full breakdown of *why* each row matters: [Module 04.2](../README.md#securing-state-in-s3).
