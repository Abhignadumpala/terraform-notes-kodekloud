# 📘 Module 6.4: AWS IAM with Terraform

> Earlier I learned how to create an IAM user by hand, in the console ([6.2](../module-06.2-demo-iam/README.md)), and from the CLI ([6.3](../module-06.3-programmatic-access/README.md)). Now let's do it with Terraform.

---

## Introduction

A console click, a CLI command, and a Terraform resource block all create the same thing: an IAM user. The difference is that once it's a resource block, it's version-controlled, repeatable, and part of the same `plan`/`apply` workflow as every other resource in this repo — no clicking or one-off commands required.

---

## Creating an IAM User Resource

Terraform resource types are prefixed with the provider name — `aws_iam_user` is the IAM-user resource in the `aws` provider. Its full list of arguments and attributes is on the [`aws_iam_user` resource page](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user) in the Terraform Registry — that's the source of truth for this resource, not this note. It needs one required argument, `name`, and accepts optional ones like `tags`:

```hcl
resource "aws_iam_user" "admin-user" {
  name = "priya"
  tags = {
    Description = "DevOps Engineer"
  }
}
```

`admin-user` here is the Terraform-local resource name (how I refer to this block elsewhere in the config) — it doesn't have to match `name = "priya"`, the actual IAM username AWS will see.

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

Both problems come from one missing thing: a `provider "aws"` block. Its full configuration reference — every argument it accepts, including the credential-related ones — is on the [AWS Provider docs page](https://registry.terraform.io/providers/hashicorp/aws/latest/docs). At its simplest, it can take the region and credentials directly:

```hcl
provider "aws" {
  region     = "us-west-2"
  access_key = "AKIAI44QH8DHBEXAMPLE"
  secret_key = "je7MtGbClwBF/2tk/h3yCo8n..."
}

resource "aws_iam_user" "admin-user" {
  name = "priya"
  tags = {
    Description = "DevOps Engineer"
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
      + name          = "priya"
      + path          = "/"
      + tags          = {
          + "Description" = "DevOps Engineer"
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

The hardcoded `access_key`/`secret_key` above is the version to avoid. The provider's [Authentication and Configuration guide](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration) lists every supported way to supply credentials — these two are the two I'd actually reach for, both of which keep the secret out of the `.tf` file entirely:

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

## Least Privilege: Priya Starts With Nothing

A freshly-created `aws_iam_user` has zero permissions — same as when I created a user by hand in [6.2](../module-06.2-demo-iam/README.md#creating-an-iam-user-lucy). The right way to grant access is incrementally: attach only the specific policy she actually needs, not more. Terraform models this as two separate concerns — a **policy** (the permission document) and an **attachment** (granting that policy to a specific user) — matching the policy/user split from [6.1](../module-06.1-introduction-to-iam/README.md#assigning-permissions).

---

## Writing the Policy Document

Same JSON shape as the `AdministratorAccess` policy from [6.1](../module-06.1-introduction-to-iam/README.md#assigning-permissions) — `Effect`, `Action`, `Resource`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
```

---

## The `aws_iam_policy` Resource

The [`aws_iam_policy` resource page](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) lists one mandatory argument: `policy`, the JSON document itself, as a string. A **heredoc** (`<<EOF ... EOF`) embeds that multi-line JSON string directly in the `.tf` file, without needing an external file or `jsonencode()`:

```hcl
resource "aws_iam_policy" "adminUser" {
  name   = "AdminUsers"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
EOF
}
```

---

## Attaching the Policy to the User

Creating the policy doesn't grant it to anyone by itself — it just exists as an object AWS knows about. Granting it needs an [`aws_iam_user_policy_attachment`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_policy_attachment) — that Registry page is where to check its exact arguments any time this note isn't enough. It takes the username and the policy's ARN:

```hcl
resource "aws_iam_user_policy_attachment" "priya-admin-access" {
  user       = aws_iam_user.admin-user.name
  policy_arn = aws_iam_policy.adminUser.arn
}
```

`aws_iam_user.admin-user.name` and `aws_iam_policy.adminUser.arn` both reference other resources in this same config — Terraform reads that as a dependency and creates the user and the policy first, then the attachment, automatically.

---

## Deploying All Three Together

```bash
terraform plan
terraform apply
```

```
aws_iam_user.admin-user: Creating...
aws_iam_policy.adminUser: Creating...
aws_iam_user.admin-user: Creation complete after 0s [id=priya]
aws_iam_policy.adminUser: Creation complete after 0s
aws_iam_user_policy_attachment.priya-admin-access: Creating...
aws_iam_user_policy_attachment.priya-admin-access: Creation complete after 0s

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.
```

If `priya` already exists from an earlier `apply` (just the user, no policy yet), adding the policy and attachment resources to the same config and running `apply` again only creates those two — Terraform leaves the already-applied user alone. That's the incremental, least-privilege workflow from the top of this section, done for real: start with a user that has nothing, then grant exactly what's needed, as its own separate `apply`.

---

## An Alternative: Reading the Policy From a File

Instead of a heredoc, the policy document can live in its own file (e.g. `admin-policy.json`, alongside the `.tf` files) and get pulled in with the built-in `file()` function:

```hcl
resource "aws_iam_policy" "adminUser" {
  name   = "AdminUsers"
  policy = file("admin-policy.json")
}
```

Same result either way — a heredoc keeps everything in one `.tf` file, a separate `.json` file keeps the policy document readable on its own and reusable across multiple resources if needed.

---

## Summary

- ✅ `aws_iam_user` is a resource block like any other — required `name`, optional `tags`
- ✅ `terraform plan` right after `init` fails without a region and credentials — both come from the `provider "aws"` block
- ✅ `arn`, `id`, `unique_id` show as `(known after apply)` in the plan — AWS assigns them at creation time
- ✅ Hardcoding `access_key`/`secret_key` in the provider block works, but leaks the secret into version control if the file is ever committed
- ✅ `aws configure` (writes `~/.aws/credentials`) or exported `AWS_*` environment variables both keep credentials out of the `.tf` files entirely
- ✅ `aws_iam_policy` holds the permission document (JSON, via heredoc or `file()`); `aws_iam_user_policy_attachment` is the separate resource that actually grants it to a user
- ✅ Referencing `aws_iam_user.admin-user.name` and `aws_iam_policy.adminUser.arn` from the attachment resource creates an automatic dependency — user and policy first, attachment after

---

## Key Takeaway

**An IAM user is just another Terraform resource, and so is a policy — the only thing that actually grants access is the separate attachment resource linking the two together.**

- ✅ Same `plan`/`apply` workflow as every other resource in this repo
- ⚠️ `access_key`/`secret_key` in the provider block is a real secret sitting in plain text — use `aws configure` or environment variables instead, same as [6.3](../module-06.3-programmatic-access/README.md)
- ✅ A user existing and a user having permissions are two different resources — creating `aws_iam_policy` alone grants nothing until it's attached

---

## Practice & Next Steps

Configure credentials with `aws configure` (not hardcoded in `.tf`), then run `terraform apply` on the `aws_iam_user.admin-user` block above and confirm the user shows up in the IAM console. Once that's applied, add the `aws_iam_policy` and `aws_iam_user_policy_attachment` blocks and `apply` again — confirm the plan only shows 2 to add, not 3, since the user is already there. Try writing a narrower policy than `AdministratorAccess` (e.g. the EC2 read-only JSON from [6.1](../module-06.1-introduction-to-iam/README.md#custom-policies)) and attaching that instead.

Next up in Module 6: [Introduction to AWS S3](../module-06.5-introduction-to-s3/README.md) — the other AWS service the [4.1 purpose-of-state](../../module-04-terraform-state/module-04.1-purpose-of-state/README.md) notes have been leaning on this whole time.
