# 📘 Module 6.1: Introduction to IAM

> AWS won't let anything touch a resource without permission first — IAM is where I define who (or what) is allowed to do what.

---

## Introduction

Every AWS lab in this repo so far has quietly assumed I already have permission to create the EC2 instances, S3 buckets, and DynamoDB tables Terraform asks for. The [4.1 purpose-of-state](../../module-04-terraform-state/module-04.1-purpose-of-state/README.md) and [5.9 terraform block](../../module-05-working-with-terraform/module-05.9-the-terraform-block/README.md) notes both use an S3 backend without ever explaining *why* my AWS credentials are allowed to touch that bucket in the first place. That's the gap IAM (Identity and Access Management) fills — it's the system that decides who gets to do what to which AWS resource, and it's what my AWS provider is actually authenticating against every time I run `terraform plan`.

Module 6 is an AWS-services detour before I go further with Terraform: IAM first, then S3 and DynamoDB — the exact two services the state backend from Module 4 already leans on.

---

## Root Account vs IAM Users

Signing up for AWS with an email and password creates the **root account** — full, unrestricted access to everything in that account, comparable to `root` on Linux or Administrator on Windows.

AWS's own guidance is blunt about this: don't use the root account for daily work. Use it once, to create individual **IAM users**, then lock the root credentials away (MFA on it, credentials not stored anywhere routine) and do everything else as one of those IAM users instead.

So a small team — Lucy, Max, Abdul, Lee — each gets their own IAM user, created from the root account, instead of everyone sharing root logins.

---

## Two Kinds of Access

An IAM user can be given either or both of:

1. **Console access** — a username and password to sign in to the AWS Management Console (the web UI).
2. **Programmatic access** — an access key ID and secret access key, used by the CLI, SDKs, or (relevant here) Terraform's AWS provider.

```bash
aws s3api create-bucket --bucket my-bucket --region us-east-1
```

That command only works if whatever credentials the AWS CLI is using resolve to an IAM identity with `s3:CreateBucket` permission. Access keys authenticate the *request*; they don't grant console login, and console credentials don't work as CLI/API keys — the two are separate.

---

## Assigning Permissions

A new IAM user starts with **zero permissions** — least privilege by default. Permissions come from **policies**, JSON documents attached to a user, group, or role.

AWS ships managed policies for common cases. `AdministratorAccess` is the broadest one:

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

`"Action": "*"` on `"Resource": "*"` — every action, every resource. That's what I'd attach to someone like Lucy if she's the project's technical lead and genuinely needs full account access. AWS also has narrower managed policies for specific jobs (billing, database admin, networking) — the point of a *managed* policy is I don't write these by hand, AWS maintains them.

### Groups, for Shared Permissions

If Max, Abdul, and Lee all need the same EC2 and S3 access, I don't attach `AmazonEC2FullAccess` and `AmazonS3FullAccess` to each of them individually — I create a **group** (e.g. "Developer Group"), attach the policies to the group once, and add all three users to it. Anyone who needs something extra on top can still get a policy attached directly to their own user.

---

## IAM Roles — Permissions for AWS Services, Not People

Everything above is about human users. But an EC2 instance doesn't have an IAM user of its own, and it might still need to read from an S3 bucket. For that, AWS uses an **IAM role** instead: a set of permissions (a policy, same as before) that isn't tied to a person, but gets *assumed* — by an EC2 instance, another AWS account, or an external identity provider.

Concretely: create a role (e.g. "S3 Access Role"), attach `AmazonS3FullAccess` to it, and attach the role to the EC2 instance. The instance can now call S3 without ever holding a long-lived access key — it gets temporary credentials for as long as the role is attached.

This same mechanism is behind cross-account access, and behind letting users from an external identity source (like an organization's Active Directory) get *temporary* AWS access without becoming full-blown IAM users.

---

## Custom Policies

Managed policies cover common cases; a custom policy is for something specific. If I only want a user able to tag and untag EC2 instances — nothing else:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateTags",
                "ec2:DeleteTags"
            ],
            "Resource": "*"
        }
    ]
}
```

Same JSON shape as a managed policy — `Effect`, `Action`, `Resource` — just scoped to exactly the actions I listed instead of `*`.

---

## Human Users: Federation Over Individual IAM Users

For a team like Lucy, Max, Abdul, and Lee, what I'd actually set up isn't four individual IAM users with access keys — it's federation through **IAM Identity Center** (AWS's SSO service), giving each person temporary credentials instead of long-lived ones.

AWS's own guidance is direct about this: require human users to access AWS through federation with an identity provider, using temporary credentials, and reserve IAM users for the specific cases federation doesn't cover — service accounts, break-glass access, and similar exceptions.

The reasoning is simple: a long-lived access key stays valid indefinitely until someone notices and rotates it. Temporary credentials from federation (or from a role) expire on their own, so a leaked one has a much smaller window to cause damage.

None of the underlying concepts change because of this — users, groups, roles, and policies all still work exactly as described above. What changes is *how* a person's identity gets provisioned in the first place: through Identity Center rather than as a standalone IAM user with an access key. The IAM role pattern for AWS services (EC2 → S3, above) is already the recommended approach either way — no gap there.

---

## Summary

IAM controls who — human or AWS service — can do what to which resource. I covered:

- ✅ Root account vs. IAM users, and why root should only be used to create the latter
- ✅ Console access (password) vs. programmatic access (access key ID + secret), and that they're separate credential types
- ✅ Policies (JSON) as the actual permission grant — managed policies (`AdministratorAccess`) vs. custom ones
- ✅ Groups, for attaching one set of policies to many users at once
- ✅ Roles, for giving an AWS *service* (not a person) temporary, assumable permissions
- ✅ For human users, federation through IAM Identity Center is the recommended path — individual IAM users with access keys are for the exceptions federation doesn't cover

---

## Key Takeaway

**IAM = who's allowed to do what, to which resource — and that "who" can be a person or an AWS service.**

- ✅ Root account: create IAM users with it, then stop using it
- ✅ Console access and programmatic access (access keys) are separate credential types
- ✅ Policies (JSON: `Effect`/`Action`/`Resource`) are the actual grant — managed or custom
- ✅ Groups share policies across multiple users; roles give services (like EC2) temporary, assumable permissions instead of long-lived keys
- ⚠️ For people, federation through IAM Identity Center beats a standalone IAM user with an access key — IAM users are for service accounts and the specific cases federation can't cover

---

## Practice & Next Steps

In the AWS Console (or a sandbox account), create one IAM user with only programmatic access, attach the custom `ec2:CreateTags`/`ec2:DeleteTags` policy above (nothing else), and confirm with the CLI that tagging an EC2 instance works but, say, `aws ec2 describe-instances` fails with an `AccessDenied` error. That failure is IAM's least-privilege model working as designed — next up in this module: a hands-on IAM demo, programmatic access in practice, and then wiring IAM users/policies into Terraform itself, before moving on to S3 and DynamoDB.
