# Hands-On Lab: AWS IAM with Terraform

> Companion hands-on lab for [Module 6.4: AWS IAM with Terraform](../README.md). Code lives in [`iam-user-code/`](iam-user-code) — `cd` into that folder and use standard `terraform init`/`plan`/`apply`.

---

## What I Built

Two stages, run as two separate `apply`s — matching the least-privilege flow from the [module note](../README.md#least-privilege-priya-starts-with-nothing): create the user first with nothing attached, then grant permissions as its own step.

- `aws_iam_user`, named `priya` (not `lucy` — that name's already taken in this account from the console walkthrough in [6.2](../../module-06.2-demo-iam/README.md), and IAM usernames have to be unique per account)
- `aws_iam_policy` — `AdminUsers`, the same `AdministratorAccess`-shaped JSON from [6.1](../../module-06.1-introduction-to-iam/README.md#assigning-permissions), via heredoc
- `aws_iam_user_policy_attachment` — grants that policy to `priya`

No hardcoded `access_key`/`secret_key` in `provider.tf` — credentials come from `aws configure`, per the [Best Practices](../README.md#best-practices-for-managing-credentials) section in the module note.

Files: `provider.tf`, `iam_user.tf`, `iam_policy.tf`, `iam_policy_attachment.tf`, `outputs.tf`.

---

## Walking Through It

### Stage 1: create the user, nothing attached yet

```bash
cd iam-user-code
terraform init
terraform plan
```

```
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

```bash
terraform apply
terraform output
```

Confirm `user_arn`/`user_name`/`unique_id` match what's on `priya`'s IAM console page — and that she has no permissions attached yet.

### Stage 2: grant the AdminUsers policy

`iam_policy.tf` and `iam_policy_attachment.tf` are already in this folder, so this is just running `plan`/`apply` again — nothing to write:

```bash
terraform plan
```

The plan should show **2 to add, 0 to change** — `priya` herself is untouched, only the new policy and attachment get created:

```bash
terraform apply
terraform output
```

`policy_arn` now shows up in the outputs, and `priya`'s **Permissions** tab in the IAM console shows `AdminUsers` attached.

### Clean up

```bash
terraform destroy
```

---

## Troubleshooting

| Issue | Fix |
|---|---|
| `EntityAlreadyExists: User with name ... already exists` | That username already exists in the account (created by hand or by a previous apply) — change `name` in `iam_user.tf` to something unused |
| `error validating provider credentials` | Run `aws configure` first — see [6.3](../../module-06.3-programmatic-access/README.md#configuring-the-aws-cli) |
| Terraform prompts for a region | Missing `provider "aws" { region = ... }` — see the module note's [Configuring the AWS Provider](../README.md#configuring-the-aws-provider) section |
| Stage 2 plan shows 3 to add, not 2 | `priya` wasn't actually applied in Stage 1 yet, or her state got destroyed since — run Stage 1's `apply` again first |
