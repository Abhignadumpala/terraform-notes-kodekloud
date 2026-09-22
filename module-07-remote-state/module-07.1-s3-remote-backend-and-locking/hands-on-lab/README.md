# Hands-On Lab: Local State → S3 Remote Backend Migration

> Companion hands-on lab for [Module 7.1: S3 Remote Backends and Native Locking](../README.md). The original course lesson's exact workflow — local state, add a backend block, `terraform init` migrates it — run for real, with an EC2 instance standing in for the lesson's `local_file` example.

---

## What I Built

- **`main.tf`** — one EC2 instance (`module-07-migration-demo`), the same "real resource, incidental to the point" role `aws_instance` plays in [4.2](../../../module-04-terraform-state/module-04.2-terraform-state-considerations/README.md)'s lab.
- **`provider.tf`** — just the AWS provider, current version (`~> 5.0`) instead of the lesson's `v3.7.0`.
- **`terraform.tf`** — the backend block, kept in its own file per the lesson's own file-organization advice. Added *after* the first `apply`, not before — that's the whole point of the demo.

No DynamoDB table anywhere in this lab — `use_lockfile = true` is the entire locking setup, replacing the lesson's `dynamodb_table = "state-locking"` + a manually pre-created table with a `lockid` hash key.

---

## Walking Through It

### 1. Apply with local state

`terraform.tf` doesn't exist yet — just `provider.tf` and `main.tf`:

```bash
terraform init && terraform apply
```

```
aws_instance.migration_demo: Creating...
aws_instance.migration_demo: Still creating... [00m10s elapsed]
aws_instance.migration_demo: Creation complete after 15s [id=i-0f9e9d0ccb6372913]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

A local `terraform.tfstate` now exists, 8,082 bytes, sitting right next to `main.tf` — the exact starting point the course lesson describes.

### 2. Add the backend block

New file, `terraform.tf`:

```hcl
terraform {
  backend "s3" {
    bucket       = "tf-migration-demo-15029"
    key          = "migration-demo/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
```

The bucket (`tf-migration-demo-15029`) was created ahead of time via the AWS CLI — versioned, encrypted, public access blocked — the same checklist [7.1](../README.md#setting-up-s3-as-a-remote-backend) walks through, just via `aws s3api` instead of its own Terraform config, since bootstrapping a backend bucket with Terraform is already covered in [7.2's lab](../../module-07.2-cross-stack-state-sharing/hands-on-lab/README.md).

### 3. `terraform init -migrate-state`, and the real migration prompt

```bash
terraform init -migrate-state
```

```
Initializing the backend...
Do you want to copy existing state to the new backend?
  Pre-existing state was found while migrating the previous "local" backend to the
  newly configured "s3" backend. No existing state was found in the newly
  configured "s3" backend. Do you want to copy this state to the new "s3"
  backend? Enter "yes" to copy and "no" to start with an empty state.

  Enter a value: yes

Successfully configured the backend "s3"! Terraform will automatically
use this backend unless the backend configuration changes.

Initializing provider plugins...
- Using previously-installed hashicorp/aws v5.100.0

Terraform has been successfully initialized!
```

Nearly word-for-word the course lesson's own migration prompt — that part of the workflow hasn't changed, only the provider version (`v5.100.0` here vs. the lesson's `v3.7.0`) and, per [7.1](../README.md), the locking mechanism this backend block uses.

Confirmed in S3 immediately after:

```bash
aws s3 ls s3://tf-migration-demo-15029/ --recursive
```

```
migration-demo/terraform.tfstate    8082
```

Same byte count as the local file — genuinely the same state, just relocated. Local `terraform.tfstate` was now 0 bytes (Terraform leaves an empty placeholder once a remote backend takes over), so I removed both it and `terraform.tfstate.backup`, per the lesson's own cleanup step.

### 4. Apply again, now against the remote backend

```bash
terraform apply
```

```
data.aws_ami.amazon_linux: Reading...
aws_instance.migration_demo: Refreshing state... [id=i-0f9e9d0ccb6372913]

No changes. Your infrastructure matches the configuration.
Releasing state lock. This may take a few moments...

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

> 📌 One more small drift from the lesson's own example output: the lesson shows an explicit `Acquiring state lock. This may take a few moments...` line at the *start* of the apply. This run only printed `Releasing state lock...` at the end — the CLI's own lock-related messaging has changed since the lesson was recorded, not just the locking mechanism underneath it.

### 5. Confirm the lock file name, from the version history

The bucket's versioning kept every revision, including every time the lock file was created and deleted across steps 3 and 4:

```bash
aws s3api list-object-versions --bucket tf-migration-demo-15029 --query "Versions[].Key"
```

```
"migration-demo/terraform.tfstate"
"migration-demo/terraform.tfstate.tflock"
"migration-demo/terraform.tfstate.tflock"
"migration-demo/terraform.tfstate.tflock"
```

`<key>.tflock`, exactly as [7.1](../README.md#native-locking-version-history-and-the-lock-file-name) and [7.2's lab](../../module-07.2-cross-stack-state-sharing/hands-on-lab/README.md#3-catch-the-lock-file-live-and-resolve-71s-open-question) both found — a second, independent confirmation that the `.terraform.lock.terraform` mismatch [4.2](../../../module-04-terraform-state/module-04.2-terraform-state-considerations/README.md) documented doesn't reproduce on a current Terraform version.

### Clean up

```bash
terraform destroy -auto-approve
```

Then the bucket itself, since it's versioned and holds every state/lock-file revision:

```bash
aws s3api list-object-versions --bucket tf-migration-demo-15029 \
  | jq '{Objects: [(.Versions // [])[], (.DeleteMarkers // [])[] | {Key, VersionId}]}' > /tmp/delete-all.json
aws s3api delete-objects --bucket tf-migration-demo-15029 --delete file:///tmp/delete-all.json
aws s3api delete-bucket --bucket tf-migration-demo-15029
```

---

## Summary

- **Same workflow the lesson teaches:** apply on local state → add a `backend` block → `terraform init -migrate-state` → confirm the migration → remove the local state files.
- **Two real updates:** `use_lockfile = true` instead of `dynamodb_table`, current provider (`~> 5.0`) instead of `v3.7.0`.
- **One more found live:** the CLI's own lock-acquire/release messaging has changed too — current Terraform doesn't print "Acquiring state lock" on a normal apply, only "Releasing" it.
- **Confirmed twice now, independently:** the S3 lock file is genuinely `<key>.tflock` on a current Terraform version — this lab and [7.2's](../../module-07.2-cross-stack-state-sharing/hands-on-lab/README.md) both caught it live.

**Next up:** [7.2](../../module-07.2-cross-stack-state-sharing/README.md) — splitting infrastructure across more than one state file, and reading one stack's outputs from another with `terraform_remote_state`.
