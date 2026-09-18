# 📘 Module 6.4: AWS IAM with Terraform

> Earlier I created an IAM user by hand, in the console ([6.2](../module-06.2-demo-iam/README.md)). Now let's try it with Terraform.

---

## Introduction

A console click and a Terraform resource block both create the same thing: an IAM user. The difference is that once it's a resource block, it's version-controlled, repeatable, and part of the same `plan`/`apply` workflow as every other resource in this repo — no clicking required.

---

## Creating an IAM User Resource

Terraform resource types are prefixed with the provider name — `aws_iam_user` is the IAM-user resource in the `aws` provider. It needs one required argument, `name`, and accepts optional ones like `tags`:

```hcl
resource "aws_iam_user" "admin-user" {
  name = "Lucy"
  tags = {
    Description = "Technical Team Leader"
  }
}
```

`admin-user` here is the Terraform-local resource name (how I refer to this block elsewhere in the config) — it doesn't have to match `name = "Lucy"`, the actual IAM username AWS will see.

---

## `terraform init` and the First `plan`

```bash
terraform init
```

Running `terraform plan` right after `init`, with nothing else configured, usually fails two ways:

1. Terraform asks for an AWS **region** — IAM itself is global (see [6.1](../module-06.1-introduction-to-iam/README.md#finding-iam)), but Terraform's AWS provider still needs a region set, since most other resources it manages are region-specific.
2. Terraform can't find any **AWS credentials** to authenticate with.

---

## Configuring the AWS Provider

Both problems come from one missing thing: a `provider "aws"` block. At its simplest, it can take the region and credentials directly:

```hcl
provider "aws" {
  region     = "us-west-2"
  access_key = "AKIAI44QH8DHBEXAMPLE"
  secret_key = "je7MtGbClwBF/2tk/h3yCo8n..."
}

resource "aws_iam_user" "admin-user" {
  name = "Lucy"
  tags = {
    Description = "Technical Team Leader"
  }
}
```

This works — Terraform now has a region and a credential pair to authenticate with. But hardcoding `access_key`/`secret_key` directly in a `.tf` file means that secret sits in plain text, and if this file is ever committed to version control, the key is exposed to everyone with repo access, permanently, in the git history. See [Best Practices](#best-practices-for-managing-credentials) below for how to avoid this.

---

## Running `plan` and `apply`

```bash
terraform plan
```

```
Terraform will perform the following actions:

  # aws_iam_user.admin-user will be created
  + resource "aws_iam_user" "admin-user" {
      + arn           = (known after apply)
      + force_destroy = false
      + id            = (known after apply)
      + name          = "Lucy"
      + path          = "/"
      + tags          = {
          + "Description" = "Technical Team Leader"
        }
      + unique_id     = (known after apply)
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

`arn`, `id`, and `unique_id` are all `(known after apply)` — AWS assigns those once the user actually exists, so Terraform can't know them ahead of time. Everything under `+` is what I specified; everything `(known after apply)` is AWS filling in the rest.

```bash
terraform apply
```

Confirming with `yes` creates the IAM user exactly as planned.

---

## Best Practices for Managing Credentials

The hardcoded `access_key`/`secret_key` above is the version to avoid. Two better options, both of which keep the secret out of the `.tf` file entirely:

**AWS CLI configuration** — the same `aws configure` from [6.3](../module-06.3-programmatic-access/README.md#configuring-the-aws-cli), writing to `~/.aws/credentials`:

```bash
aws configure
```

```ini
[default]
aws_access_key_id = YOUR_ACCESS_KEY_ID
aws_secret_access_key = YOUR_SECRET_ACCESS_KEY
```

Terraform's AWS provider picks these up automatically — no `access_key`/`secret_key` arguments needed in the `provider` block at all.

**Environment variables** — set for the current shell session instead of written to a file:

```bash
export AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=us-west-2
```

Either way, the `provider "aws" {}` block can end up empty, or with just non-secret settings — the credentials live outside the `.tf` file, so there's nothing sensitive to accidentally commit.

---

## Summary

- ✅ `aws_iam_user` is a resource block like any other — required `name`, optional `tags`
- ✅ `terraform plan` right after `init` fails without a region and credentials — both come from the `provider "aws"` block
- ✅ `arn`, `id`, `unique_id` show as `(known after apply)` in the plan — AWS assigns them at creation time
- ✅ Hardcoding `access_key`/`secret_key` in the provider block works, but leaks the secret into version control if the file is ever committed
- ✅ `aws configure` (writes `~/.aws/credentials`) or exported `AWS_*` environment variables both keep credentials out of the `.tf` files entirely

---

## Key Takeaway

**An IAM user is just another Terraform resource — the only new piece here is where the provider gets its region and credentials from, and hardcoding them is the one option to avoid.**

- ✅ Same `plan`/`apply` workflow as every other resource in this repo
- ⚠️ `access_key`/`secret_key` in the provider block is a real secret sitting in plain text — use `aws configure` or environment variables instead, same as [6.3](../module-06.3-programmatic-access/README.md)

---

## Practice & Next Steps

Configure credentials with `aws configure` (not hardcoded in `.tf`), then run `terraform apply` on the `aws_iam_user.admin-user` block above and confirm the user shows up in the IAM console. Try adding a second `aws_iam_user` resource for a different name and applying both together in one `plan`.

Next up in Module 6: attaching IAM policies to this user through Terraform — `aws_iam_policy`, `aws_iam_user_policy_attachment`, and the managed-vs-custom policy distinction from [6.1](../module-06.1-introduction-to-iam/README.md#assigning-permissions), now as code.
