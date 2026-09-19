# Hands-On Lab: AWS IAM with Terraform

> Companion hands-on lab for [Module 6.4: AWS IAM with Terraform](../README.md). Code lives in [`iam-user-code/`](iam-user-code) — `cd` into that folder and use standard `terraform init`/`plan`/`apply`.

---

## What I Built

- `aws_iam_user`, named `priya` (not `lucy` — that name's already taken in this account from the console walkthrough in [6.2](../../module-06.2-demo-iam/README.md), and IAM usernames have to be unique per account)
- `aws_iam_policy` — `AdminUsers`, the same `AdministratorAccess`-shaped JSON from [6.1](../../module-06.1-introduction-to-iam/README.md#assigning-permissions), via heredoc
- `aws_iam_user_policy_attachment` — grants that policy to `priya`

No hardcoded `access_key`/`secret_key` in `provider.tf` — credentials come from `aws configure`, per the [Best Practices](../README.md#best-practices-for-managing-credentials) section in the module note.

Files: `provider.tf`, `iam_user.tf`, `iam_policy.tf`, `iam_policy_attachment.tf`, `outputs.tf`.

---

## Walking Through It

All three `.tf` files were already in place before the first `apply`, so `plan` picked up all three resources together — one user, one policy, one attachment:

```bash
cd iam-user-code
terraform init
terraform plan
terraform apply
```

![iam_user.tf and provider.tf open, terminal showing terraform apply's tail end: Plan 3 to add, Apply complete, Resources: 3 added, outputs policy_arn/unique_id/user_arn/user_name](images/01-apply-user-and-provider-code.png)

`provider.tf` has no `access_key`/`secret_key` — just a comment saying credentials come from `aws configure` or `AWS_*` environment variables, matching the [Best Practices](../README.md#best-practices-for-managing-credentials) section.

```bash
terraform output
```

`priya` shows up in the IAM console, alongside whatever other users already exist in the account:

![IAM users list filtered to "p", showing priya with no groups, no console access, no access key — matching a freshly-created Terraform user](images/02-iam-users-console-priya.png)

`iam_policy.tf` is the heredoc from the module note, applied as part of that same `apply`:

![iam_policy.tf: aws_iam_policy "adminUser" with a heredoc policy document, same terminal output showing the apply completing](images/03-iam-policy-heredoc-code.png)

And `priya`'s own **Permissions** tab confirms the attachment actually took — `AdminUsers`, attached directly, not through a group:

![priya's Permissions policies tab: AdminUsers, Customer managed, Attached via Directly](images/04-priya-adminusers-attached.png)

### Clean up

```bash
terraform destroy
```

---

## Applying It Incrementally Instead

Nothing stops `iam_user.tf` from being applied on its own first — just don't create `iam_policy.tf`/`iam_policy_attachment.tf` yet, run `terraform apply` (1 to add), and add the other two files later. A second `apply` at that point would show **2 to add, 0 to change** — `priya` stays untouched, only the new policy and attachment get created. That's the literal, `plan`-verified version of the least-privilege idea from the [module note](../README.md#least-privilege-priya-starts-with-nothing): start with nothing, add permissions as a deliberate, separate step.

---

## Troubleshooting

| Issue | Fix |
|---|---|
| `EntityAlreadyExists: User with name ... already exists` | That username already exists in the account (created by hand or by a previous apply) — change `name` in `iam_user.tf` to something unused |
| `error validating provider credentials` | Run `aws configure` first — see [6.3](../../module-06.3-programmatic-access/README.md#configuring-the-aws-cli) |
| Terraform prompts for a region | Missing `provider "aws" { region = ... }` — see the module note's [Configuring the AWS Provider](../README.md#configuring-the-aws-provider) section |
