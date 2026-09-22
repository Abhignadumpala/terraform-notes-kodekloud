# 📘 Module 7.3: Terraform State Commands

> [7.1](../module-07.1-s3-remote-backend-and-locking/README.md) and [7.2](../module-07.2-cross-stack-state-sharing/README.md) covered where state lives and how to share it across stacks. This is about working with a state file directly — inspecting it, renaming a resource inside it without recreating anything, and detaching a resource without destroying it — using the CLI subcommands built for exactly that, since the state file itself is off-limits to hand-editing.

---

## Introduction

The state file is JSON, and it's tempting to think "I'll just edit it" the first time something looks wrong. Don't — `terraform state <subcommand>` exists precisely so nothing has to touch that file directly. Every subcommand below does one specific, safe operation on it: list what's in there, inspect one resource closely, rename an address, download the remote copy, or remove an entry without touching real infrastructure.

```
terraform state <subcommand> [options] [address]
```

---

## `list` — What's in the State

```bash
terraform state list
```

```
aws_dynamodb_table.app_configuration
aws_s3_bucket.reports
```

Every managed resource's address, one per line. An argument after `list` filters it down to addresses matching that pattern — useful once a config has more than a handful of resources.

---

## `show` — One Resource's Full Attributes

```bash
terraform state show aws_s3_bucket.reports
```

```hcl
# aws_s3_bucket.reports:
resource "aws_s3_bucket" "reports" {
    arn                         = "arn:aws:s3:::tf-state-cmds-reports-8f2a1"
    bucket                      = "tf-state-cmds-reports-8f2a1"
    bucket_domain_name          = "tf-state-cmds-reports-8f2a1.s3.amazonaws.com"
    hosted_zone_id              = "Z3AQBSTGFYJSTF"
    id                          = "tf-state-cmds-reports-8f2a1"
    region                      = "us-east-1"
    tags                        = {
        "Description" = "..."
    }
    # ...
}
```

> ⚠️ **The exact attributes shown have moved since older material was written.** An `aws_s3_bucket` resource used to carry `acl` and an inline `versioning { enabled = ... }` block directly — current output has neither, because the AWS provider split those into their own resources (`aws_s3_bucket_acl`, `aws_s3_bucket_versioning`) a few major versions back. `terraform state show` on the bucket itself won't show versioning status anymore; that's a separate resource's state entry now. Same "one thing, several resources" split already covered in [6.6](../../module-06-aws-services-for-terraform/module-06.6-s3-with-terraform/README.md).

---

## `mv` — Rename Without Recreating

Renaming a resource in `.tf` code alone doesn't rename it in state — Terraform sees a deleted resource and a new one, and plans to destroy/recreate. `state mv` fixes the state side first:

```bash
terraform state mv aws_dynamodb_table.app_config aws_dynamodb_table.app_configuration
```

```
Move "aws_dynamodb_table.app_config" to "aws_dynamodb_table.app_configuration"
Successfully moved 1 object(s).
```

Then the `.tf` file's resource block gets the matching new name. A follow-up `apply` confirms nothing changes — the state entry now matches the config, same real DynamoDB table underneath, never destroyed:

```
No changes. Your infrastructure matches the configuration.
```

---

## `pull` — Download the Remote State

With a remote backend, the state file doesn't exist as a local file to just `cat`. `pull` fetches and prints it:

```bash
terraform state pull
```

```json
{
  "version": 4,
  "terraform_version": "1.16.1",
  "serial": 3,
  "resources": [
    {
      "mode": "managed",
      "type": "aws_dynamodb_table",
      "name": "app_configuration",
      "instances": [{ "attributes": { "hash_key": "LockID", "...": "..." } }]
    }
  ]
}
```

Pipes straight into `jq` for filtering:

```bash
terraform state pull | jq -r '.resources[] | select(.name == "app_configuration") | .instances[].attributes.hash_key'
```

```
LockID
```

---

## `rm` — Detach Without Destroying

```bash
terraform state rm aws_s3_bucket.reports
```

```
Removed aws_s3_bucket.reports
Successfully removed 1 resource instance(s).
```

The bucket is gone from `terraform state list` — but still fully live in AWS. Terraform simply stopped tracking it; nothing was deleted. Remove or comment out the matching `.tf` resource block afterward, or the next `plan` will just want to create it again from scratch (a second, unrelated resource with the same name colliding on the next `apply`).

> ⚠️ **Lock messaging has changed here too**, on top of what [7.1](../module-07.1-s3-remote-backend-and-locking/hands-on-lab/README.md#4-apply-again-now-against-the-remote-backend) already found for `apply`: older material shows `state rm` printing `Acquiring state lock...` / `Releasing state lock...` around the operation. On Terraform 1.16.1 it printed neither — just the two result lines above. Same drift, different command; worth treating any specific lock-message wording in older docs as illustrative, not something to expect verbatim.

---

## Summary

- ✅ `list` → every resource address; `show <address>` → one resource's full attributes
- ✅ `mv <old> <new>` → renames in state (matching the `.tf` rename) without destroying/recreating
- ✅ `pull` → the actual remote state JSON, pipeable into `jq`
- ✅ `rm <address>` → detaches from Terraform's tracking, leaves the real resource alone
- ⚠️ `show` on an `aws_s3_bucket` no longer includes `acl`/`versioning` inline — those moved to their own resources in a newer AWS provider version
- ⚠️ Neither `mv` nor `rm` printed lock-acquire/release messages on Terraform 1.16.1, even though older docs/examples show them for `rm`

---

## Key Takeaway

**Every state subcommand exists so the JSON file itself never has to be hand-edited — `mv` and `rm` in particular change what Terraform *tracks*, not what actually exists in AWS.**

- ✅ `mv` is a state-only rename; the real resource is untouched
- ⚠️ `rm` orphans a real resource from Terraform's management — it still exists, still costs money if it's a paid one, and nothing manages it anymore until it's imported back or deleted by hand

---

## Practice & Next Steps

Run the [hands-on lab](hands-on-lab/README.md): create two resources, rename one with `state mv` and confirm a clean `apply`, then `rm` the other and confirm — both in Terraform's state and directly against AWS — that it's untracked but still very much alive.
