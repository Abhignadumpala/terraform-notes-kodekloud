# Hands-On Lab: AWS IAM with Terraform

> Companion hands-on lab for [Module 6.4: AWS IAM with Terraform](../README.md). Code lives in [`iam-user-code/`](iam-user-code) — `cd` into that folder and use standard `terraform init`/`plan`/`apply`.

---

## What I Built

One `aws_iam_user` resource, named `priya` (not `lucy` — that name's already taken in this account from the console walkthrough in [6.2](../../module-06.2-demo-iam/README.md), and IAM usernames have to be unique per account). No hardcoded `access_key`/`secret_key` in `provider.tf` — credentials come from `aws configure`, per the [Best Practices](../README.md#best-practices-for-managing-credentials) section in the module note.

Files: `provider.tf`, `iam_user.tf`, `outputs.tf`.

---

## Walking Through It

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
```

```bash
terraform output
```

Confirm the outputs (`user_arn`, `user_name`, `unique_id`) match what's on `priya`'s IAM console page, then clean up:

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
