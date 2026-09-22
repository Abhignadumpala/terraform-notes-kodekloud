# 📘 Module 7.1: S3 Remote Backends and Native Locking

> [4.2](../../module-04-terraform-state/module-04.2-terraform-state-considerations/README.md) first covered remote backends, back when Module 4 was working through state in general. This is that topic's own home now — same core content, re-verified against the current docs, with the gaps that showed up since then filled in.

---

## Introduction

A **backend** is where Terraform stores its state file. Local (the default) works fine solo; it breaks down the moment more than one person needs to touch the same infrastructure — no shared source of truth, no locking against concurrent writes, and a state file sitting in plaintext on one laptop holding whatever secrets got created along the way (an RDS password, an access key). A **remote backend** fixes all three by moving that file somewhere shared, access-controlled, and lockable. For anything already on AWS, S3 is the natural choice.

---

## Setting Up S3 as a Remote Backend

1. **Create the bucket.** Names are globally unique across all of AWS, so it needs to be distinctive. A production bucket should also set `prevent_destroy` in its lifecycle block — an accidental `terraform destroy` should error out, not delete the bucket the whole team's state lives in.
2. **Turn on versioning** — every revision of the state file is kept, so a bad `apply` is recoverable instead of a permanent loss.
3. **Turn on server-side encryption** — everything written to the bucket is encrypted at rest by default.
4. **Block all public access** — S3 buckets are private by default, but it's easy to loosen that by accident. State holds sensitive data; this is worth setting explicitly.
5. **Set least-privilege IAM permissions** for whoever (or whatever CI job) runs Terraform: `s3:ListBucket` on the bucket, `s3:GetObject`/`s3:PutObject` on the state file, and `s3:GetObject`/`s3:PutObject`/`s3:DeleteObject` on the lock file.
6. **Point the backend block at the bucket:**

```hcl
terraform {
  backend "s3" {
    bucket       = "my-terraform-state-bucket"
    key          = "project/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
```

7. **Run `terraform init`** — it sets up the backend and, if local state already exists, offers to migrate it over.

`use_lockfile = true` is the entire native-locking setup — no DynamoDB table, no separate resource.

---

## Native Locking: Version History and the Lock File Name

Two things about native S3 locking are worth being precise about, since they've moved since this repo's earlier notes were written:

- **GA status.** Native S3 locking shipped *experimentally* in Terraform 1.10, and became **generally available in 1.11**. "1.10+" (as earlier notes put it) technically covers both, but anything built for real should target 1.11 or later, not the experimental release.
- **Lock file naming.** The lock file sits next to the state file, sharing its name with a `.tflock` extension appended — `project/terraform.tfstate` gets locked by `project/terraform.tfstate.tflock`. [4.2's hands-on lab](../../module-04-terraform-state/module-04.2-terraform-state-considerations/hands-on-lab/README.md#5-simulate-a-held-lock) found a real bucket producing `.terraform.lock.terraform` instead — a mismatch from a Terraform version that predated the naming the docs describe now. Worth checking this repo's own lab in [7.2](../module-07.2-cross-stack-state-sharing/hands-on-lab/README.md) — built on Terraform 1.16 — to see whether that discrepancy still holds on a current version.

---

## Migrating from DynamoDB to Native S3 Locking

For an existing setup still using `dynamodb_table`:

1. Upgrade to Terraform 1.11 or later.
2. Add `use_lockfile = true` to the backend block.
3. Test in a non-production environment first.
4. Run `terraform init` to reconfigure the backend.
5. Confirm locking still works with an `apply`.
6. Remove `dynamodb_table` once confident.
7. Delete the DynamoDB table itself — nothing needs it anymore.

Both mechanisms can run at the same time during the migration, which gives a safety net while testing.

---

## Summary

- ✅ A backend is where state lives; remote (S3, for AWS) fixes the three local-state problems — shared access, locking, and secrets on a laptop
- ✅ Setting up S3 as a backend: bucket → versioning → encryption → block public access → least-privilege IAM → `backend "s3" { ... use_lockfile = true }` → `terraform init`
- ⚠️ Native S3 locking: experimental in 1.10, GA since **1.11** — build against 1.11+
- ⚠️ The lock file is `<key>.tflock`, per current docs — but real-world behavior has drifted from that on at least one older CLI version; verify against a current one rather than trusting either source blindly
- ✅ Migrating off DynamoDB: upgrade, add `use_lockfile`, test, reinit, confirm, remove the old parameter, delete the table

---

## Key Takeaway

**A remote backend turns state from "a file on my disk" into shared, locked, versioned infrastructure in its own right — and as of Terraform 1.11, S3 alone (no DynamoDB) is enough to do all three.**

- ✅ Encryption + versioning + blocked public access + least-privilege IAM is the full security checklist, not just "put it in S3"
- ⚠️ Don't assume the lock file's name matches the docs on an old CLI — check the bucket

---

## Practice & Next Steps

Set up an S3 backend for a small project, confirm the lock file's actual name in the bucket after one `apply`, and compare it against what's documented here. Then move to [7.2](../module-07.2-cross-stack-state-sharing/README.md): splitting infrastructure across more than one state file, and reading one stack's outputs from another with `terraform_remote_state`.
