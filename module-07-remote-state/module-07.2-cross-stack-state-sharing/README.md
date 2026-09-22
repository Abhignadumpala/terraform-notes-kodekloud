# 📘 Module 7.2: Cross-Stack State Sharing with `terraform_remote_state`

> [7.1](../module-07.1-s3-remote-backend-and-locking/README.md) covered *where* state lives. This is about a different problem: once infrastructure is split across more than one Terraform config — a network stack, a compute stack, a database stack — how does the compute stack find out what VPC the network stack actually created?

---

## Introduction

Every lab in this repo so far has been one Terraform config managing everything it needs, end to end. Real infrastructure doesn't usually stay that way — a team splits state on purpose, so a network change doesn't force a plan against production compute, and so different people can own different stacks. But splitting state creates a new problem immediately: the compute stack needs the network stack's VPC ID and subnet ID, and it can't just declare `resource "aws_vpc"` again — that VPC already exists, owned by a different config entirely.

`terraform_remote_state` is the data source built for exactly this: read another Terraform config's *outputs*, from its state file, without owning or re-declaring any of its resources.

---

## The `terraform_remote_state` Data Source

```hcl
data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "my-terraform-state-bucket"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}
```

`backend`/`config` here just describe *where to read from* — the same bucket/key/region a `backend "s3"` block would use, except this config isn't managing that state, only reading it. Once declared, every output the network stack defined is available as `data.terraform_remote_state.network.outputs.<name>`:

```hcl
resource "aws_instance" "app" {
  subnet_id              = data.terraform_remote_state.network.outputs.subnet_id
  vpc_security_group_ids = [data.terraform_remote_state.network.outputs.security_group_id]
  # ...
}
```

No hardcoded IDs, no copy-pasting a VPC ID from one team's Slack message into another team's `.tfvars` file — the compute stack always reads whatever the network stack's *last apply* actually produced.

> 💡 Only attributes the network stack explicitly declared as `output` blocks are reachable this way. If the network stack never output `subnet_id`, the compute stack can't get at it through this data source — the fix is adding the output to the network stack, not working around it in the reader.

---

## The Catch: Reading Outputs Means Reading the Whole State File

This is the part that's easy to miss: `terraform_remote_state` only *exposes* outputs, but to get them, Terraform has to download and read the **entire state file** the config is pointed at — not just the outputs section. Anyone with read access to run a plan against the compute stack effectively has read access to everything in the network stack's state, including any non-sensitive-looking resource attribute that happens to sit next to the outputs.

Two practical consequences:

- **IAM access to a stack's state bucket/key is IAM access to everything in that state**, not just what it chooses to output. Scoping S3 read permissions down to "only this key" (from [7.1](../module-07.1-s3-remote-backend-and-locking/README.md#setting-up-s3-as-a-remote-backend)) matters more once other stacks start reading it.
- Marking an output `sensitive = true` hides it from CLI output and logs, but does **not** stop `terraform_remote_state` from being able to read it if the reader has state-file access — sensitivity is a display concern, not an access-control one.

---

## Summary

- ✅ `terraform_remote_state` reads another config's *outputs*, by pointing at the same backend/key it stores state under
- ✅ The compute stack never redeclares the network stack's resources — it references `data.terraform_remote_state.network.outputs.*` instead
- ⚠️ Reading outputs requires read access to the **entire** source state file, not just the outputs — `sensitive = true` on an output doesn't block that
- ✅ An output has to exist on the source stack before anything downstream can read it

---

## Key Takeaway

**Splitting infrastructure into multiple state files solves ownership and blast-radius problems, but immediately creates a wiring problem — `terraform_remote_state` is the wiring, at the cost of every reader needing access to the source's whole state file, not just what it outputs.**

- ✅ Same backend config as a `backend "s3"` block, just for reading instead of owning
- ⚠️ State-file access is state-file access — scope IAM to the bucket/key, not just "trust the outputs are safe"

---

## Practice & Next Steps

Run the [hands-on lab](hands-on-lab/README.md): a `network` stack (VPC, subnet, security group) and a `compute` stack (one EC2 instance) as two entirely separate Terraform configs sharing one S3 backend bucket, wired together with `terraform_remote_state` — plus a real check of the S3 lock file's actual name on Terraform 1.16, against [7.1](../module-07.1-s3-remote-backend-and-locking/README.md#native-locking-version-history-and-the-lock-file-name)'s open question.
