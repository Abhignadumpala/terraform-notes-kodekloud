# Hands-On Lab: Terraform State Commands

> Companion hands-on lab for [Module 7.3: Terraform State Commands](../README.md). Two real resources, one remote S3 backend, every `terraform state` subcommand run for real against them.

---

## What I Built

- **`aws_dynamodb_table.app_config`** — renamed to `app_configuration` mid-lab with `state mv`, matching the course lesson's own DynamoDB rename example.
- **`aws_s3_bucket.reports`** — detached with `state rm`, then manually deleted via the AWS CLI afterward, since Terraform no longer tracked it.
- Backed by a remote S3 backend (`tf-state-cmds-demo-<random>`), so `state pull` has something real to download instead of just `cat`-ing a local file.

---

## Walking Through It

### 1. Apply both resources

```bash
terraform init && terraform apply
```

```
aws_dynamodb_table.app_config: Creation complete after 8s [id=app-config]
aws_s3_bucket.reports: Creation complete after 4s [id=tf-state-cmds-reports-8f2a1]

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

> 💡 Hit a real `InvalidTag` error on the first attempt — a tag value with a comma in it (`"...detached with state rm, not destroyed"`) got rejected by S3's tagging API. AWS tag values don't allow commas; removed it and re-applied clean. Small thing, but the kind of error that only shows up by actually running the `apply`, not by reading the HCL.

### 2. `list` and `show`

```bash
terraform state list
```

```
aws_dynamodb_table.app_config
aws_s3_bucket.reports
```

```bash
terraform state show aws_s3_bucket.reports
```

```hcl
# aws_s3_bucket.reports:
resource "aws_s3_bucket" "reports" {
    arn                         = "arn:aws:s3:::tf-state-cmds-reports-8f2a1"
    bucket                      = "tf-state-cmds-reports-8f2a1"
    bucket_domain_name          = "tf-state-cmds-reports-8f2a1.s3.amazonaws.com"
    tags                        = {
        "Description" = "State commands demo - detached with state rm not destroyed"
    }
    # ... (no acl, no versioning block - see 7.3's note on why)
}
```

### 3. Rename with `mv`

Changed the resource's local name in `main.tf` from `app_config` to `app_configuration`, then moved it in state first:

```bash
terraform state mv aws_dynamodb_table.app_config aws_dynamodb_table.app_configuration
```

```
Move "aws_dynamodb_table.app_config" to "aws_dynamodb_table.app_configuration"
Successfully moved 1 object(s).
```

```bash
terraform apply
```

```
No changes. Your infrastructure matches the configuration.
Releasing state lock. This may take a few moments...

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

Confirmed: the real DynamoDB table (`id=app-config` — the `name` argument, unrelated to the Terraform-local resource name that just got renamed) was never touched.

### 4. `pull`, and a `jq` filter

```bash
terraform state pull | head -6
```

```json
{
  "version": 4,
  "terraform_version": "1.16.1",
  "serial": 3,
  "lineage": "75859b88-ab41-51e0-05fd-a4468c7ae7aa",
  "outputs": {},
```

```bash
terraform state pull | jq -r '.resources[] | select(.name == "app_configuration") | .instances[].attributes.hash_key'
```

```
LockID
```

### 5. `rm`, and proof the bucket survives

```bash
terraform state rm aws_s3_bucket.reports
```

```
Removed aws_s3_bucket.reports
Successfully removed 1 resource instance(s).
```

No lock-acquire/release messages — see [7.3's note](../README.md#rm--detach-without-destroying) on that. Confirmed the bucket is gone from Terraform's view but still real:

```bash
terraform state list
```

```
aws_dynamodb_table.app_configuration
```

```bash
aws s3api head-bucket --bucket tf-state-cmds-reports-8f2a1
```

```json
{
  "BucketArn": "arn:aws:s3:::tf-state-cmds-reports-8f2a1",
  "BucketRegion": "us-east-1"
}
```

Bucket's still there, `head-bucket` succeeds, and it's nowhere in `state list` anymore.

### Clean up

The DynamoDB table is still Terraform-managed, so:

```bash
terraform destroy -auto-approve
```

But the S3 bucket isn't — `state rm` orphaned it — so it needed a manual delete instead of `terraform destroy` touching it:

```bash
aws s3 rm s3://tf-state-cmds-reports-8f2a1 --recursive
aws s3api delete-bucket --bucket tf-state-cmds-reports-8f2a1
```

Then the backend bucket itself (same versioned-bucket cleanup as [7.1](../../module-07.1-s3-remote-backend-and-locking/hands-on-lab/README.md#clean-up)/[7.2](../../module-07.2-cross-stack-state-sharing/hands-on-lab/README.md)).

---

## Summary

- **`mv`** confirmed with a real follow-up `apply`: `No changes` — the table was renamed in state, never recreated.
- **`rm`** confirmed two ways: gone from `state list`, but `head-bucket` still succeeds against the real bucket.
- **`pull`** confirmed real remote JSON, current `terraform_version` (1.16.1, vs. the course lesson's own example showing `0.13.0`), piped through `jq` exactly as documented.
- **A detached resource needs manual cleanup** — `terraform destroy` won't touch something `state rm` already orphaned; deleted the bucket by hand.

**Next up:** that's the last lesson in this course module — Module 7 (Remote State) is done: backends and locking in 7.1, cross-stack sharing in 7.2, state commands here in 7.3.
