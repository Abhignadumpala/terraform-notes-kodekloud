# Hands-On Lab: S3 with Terraform

> Companion hands-on lab for [Module 6.6: S3 with Terraform](../README.md). Code lives in [`s3-bucket-code/`](s3-bucket-code) — `cd` into that folder and use standard `terraform init`/`plan`/`apply`.

---

## What I Built

- `aws_iam_user` (`meena`) + `aws_iam_group` (`finance-analysts`) + `aws_iam_group_membership` — in a real account this group and its members would already exist; I create them here so the lab is self-contained and can be applied on its own
- `aws_s3_bucket` (`finance`) — named `finance-<my-account-id>` instead of the module note's literal `finance-21092020`, since that name is almost certainly already taken by someone else (bucket names are globally unique by default — see [6.5](../../module-06.5-introduction-to-s3/README.md#bucket-fundamentals))
- `aws_s3_object` — uploads `finance-2020.txt` (a plain-text stand-in for the module note's `.doc` example) into the bucket via `source`
- `data.aws_iam_group` + `aws_s3_bucket_policy` — grants `finance-analysts`' members access, listing their individual ARNs (`users[*].arn`) since a group's own ARN isn't a valid bucket policy principal

No hardcoded `access_key`/`secret_key` in `provider.tf` — credentials come from `aws configure`, per the [Best Practices](../../module-06.4-aws-iam-with-terraform/README.md#best-practices-for-managing-credentials) section back in 6.4.

Files: `provider.tf`, `iam_group.tf`, `s3_bucket.tf`, `s3_object.tf`, `s3_bucket_policy.tf`, `outputs.tf`, `finance-2020.txt`.

---

## Walking Through It

```bash
cd s3-bucket-code
terraform init
terraform plan
terraform apply
```

`terraform validate` and `terraform plan` both come back clean — 6 resources to add (user, group, membership, bucket, object, policy), 0 to change, 0 to destroy — but I haven't run `terraform apply` for real yet. Once I do, I'll fill this section in with the actual output and console screenshots, same as [6.4](../../module-06.4-aws-iam-with-terraform/hands-on-lab/README.md).

### Clean up

```bash
terraform destroy
```

---

## Troubleshooting

| Issue | Fix |
|---|---|
| `BucketAlreadyExists` | Someone else already owns that exact bucket name — bucket names are global. Change `bucket` in `s3_bucket.tf` to something else, or confirm the `data.aws_caller_identity.current.account_id` interpolation is actually resolving |
| `EntityAlreadyExists: User with name ... already exists` / `Group with name ... already exists` | That name already exists in the account from a previous apply or another lab (e.g. `priya`/`raj` from [6.4](../../module-06.4-aws-iam-with-terraform/hands-on-lab/README.md)) — change the colliding name |
| `MalformedPolicy: Invalid principal in policy` | Usually means the `Principal.AWS` list ended up empty or contains something that isn't a valid ARN — check that `finance-analysts-membership` actually applied before the bucket policy did |
| `error validating provider credentials` | Run `aws configure` first — see [6.3](../../module-06.3-programmatic-access/README.md#configuring-the-aws-cli) |
