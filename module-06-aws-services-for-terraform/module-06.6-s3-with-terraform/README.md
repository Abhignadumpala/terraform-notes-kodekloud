# 📘 Module 6.6: S3 with Terraform

> [6.5](../module-06.5-introduction-to-s3/README.md) covered what a bucket and an object actually are. This is where I actually create one with Terraform, upload a file into it, and grant an IAM group's members access to it.

---

## Introduction

In this module, I learn how to create and manage an S3 bucket using Terraform. I'll cover:

- Creating an S3 bucket
- Uploading a file to the bucket
- Attaching a bucket policy that grants access to an existing IAM entity

> 🧪 **Hands-on lab:** [S3 with Terraform](hands-on-lab/README.md) — deploy a bucket, upload a file into it, and grant a `finance-analysts` group's members access via a bucket policy.

---

## Creating an S3 Bucket

To create an S3 bucket, I use the `aws_s3_bucket` resource — [the source of truth for its arguments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket).

```hcl
resource "aws_s3_bucket" "finance" {
  bucket = "finance-21092020"
  tags = {
    Description = "Finance and Payroll"
  }
}
```

Running `terraform apply` plans and creates the bucket:

```
$ terraform apply
Terraform will perform the following actions:

  # aws_s3_bucket.finance will be created
  + resource "aws_s3_bucket" "finance" {
      + arn    = (known after apply)
      + bucket = "finance-21092020"
    }

Plan: 1 to add, 0 to change, 0 to destroy.

Enter a value: yes
aws_s3_bucket.finance: Creating...
aws_s3_bucket.finance: Creation complete after 0s [id=finance-21092020]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

Terraform tracks the bucket's state in the local `terraform.tfstate` file.

> ⚠️ `finance-21092020` won't actually be available to me — bucket names are unique across every AWS account by default (see [6.5](../module-06.5-introduction-to-s3/README.md#bucket-fundamentals)), and that exact name is very likely already taken by someone else. My [hands-on lab](hands-on-lab/README.md) appends my own account ID to the name so it's guaranteed to be mine.

---

## Uploading a File to the S3 Bucket

After creating the bucket, the next step is uploading a file. The resource for this is `aws_s3_object` — [the source of truth for its arguments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object). (`aws_s3_bucket_object` also exists but has been deprecated since AWS provider v4.0 — new configs should use `aws_s3_object`.) The key arguments:

- the bucket reference
- the key, which is the file's name inside the bucket
- the file's content — via `source` (a path to a local file) or `content` (a literal string)

```hcl
resource "aws_s3_object" "finance-2020" {
  bucket = aws_s3_bucket.finance.id
  key    = "finance-2020.doc"
  source = "/root/finance/finance-2020.doc"
}
```

> 💡 `source` uploads a file straight from disk — the right choice for anything that isn't plain text. `content = file("/root/finance/finance-2020.doc")` reads the file into memory as a string first, and Terraform's `file()` function only works on valid UTF-8 text, so a binary file like a `.doc` would fail with that approach.

After updating the config, `terraform apply` uploads the file.

---

## Applying a Bucket Policy

To grant access to members of an IAM group named `finance-analysts`, I attach a bucket policy to the S3 bucket. I look the group up with a data source rather than hardcoding anything about it:

```hcl
data "aws_iam_group" "finance-data" {
  group_name = "finance-analysts"
}
```

> ⚠️ IAM groups can't be used as a `Principal` in a bucket policy — only individual IAM users, roles, an AWS account, or an AWS service can. The policy below reflects that: it lists each group member's own ARN (`users[*].arn`, exported by the data source above) instead of the group's ARN.

```hcl
resource "aws_s3_bucket_policy" "finance-policy" {
  bucket = aws_s3_bucket.finance.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "*",
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.finance.id}/*",
      "Principal": {
        "AWS": ${jsonencode(data.aws_iam_group.finance-data.users[*].arn)}
      }
    }
  ]
}
EOF
}
```

`terraform apply` attaches the policy, granting full access (`"Action": "*"`) to everyone currently in `finance-analysts`.

> ⚠️ Same least-privilege point as [6.1](../module-06.1-introduction-to-iam/README.md#assigning-permissions) and [6.5](../module-06.5-introduction-to-s3/README.md#bucket-policies-in-practice) — `"Action": "*"` is illustrative here, not something I'd actually attach in a real account. A real finance-analyst policy would scope `Action` down to something like `s3:GetObject`/`s3:ListBucket`.

---

## Summary

- ✅ `aws_s3_bucket` creates the bucket; `aws_s3_object` (not the deprecated `aws_s3_bucket_object`) uploads a file into it, via `source` (a file path) or `content` (a literal string)
- ✅ `aws_s3_bucket_policy` is the separate resource that actually grants access — same pattern as `aws_iam_policy` + `aws_iam_user_policy_attachment` from [6.4](../module-06.4-aws-iam-with-terraform/README.md)
- ✅ A `data` source (`aws_iam_group`) looks up an IAM entity that already exists, instead of hardcoding its ARN
- ⚠️ IAM groups can't be a bucket policy's `Principal` — list the group's member ARNs (`users[*].arn`) instead

---

## Key Takeaway

**Creating a bucket, uploading into it, and granting access to it are three separate resources — same "existence ≠ permissions" idea as IAM, just for S3.**

- ✅ `aws_s3_bucket` → `aws_s3_object` → `aws_s3_bucket_policy`, each one a distinct resource block
- ⚠️ A group's ARN doesn't work as a bucket policy principal — resolve it down to individual user ARNs first

---

## Practice & Next Steps

Run the [hands-on lab](hands-on-lab/README.md): create the bucket, upload a file, and confirm the bucket policy actually took by checking the bucket's **Permissions** tab in the console. Then try scoping the policy's `Action` down from `"*"` to just `["s3:GetObject", "s3:ListBucket"]` and re-apply — confirm the plan shows the policy updating in place, not the bucket being replaced.

Next up in Module 6: Introduction to DynamoDB.
