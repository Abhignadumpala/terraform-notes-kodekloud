# 📘 Module 6.2: Demo IAM — Users, Groups, Policies, and Roles in the Console

> [6.1](../module-06.1-introduction-to-iam/README.md) covered IAM as theory — root vs. users, policies, groups, roles. This lesson is the same ideas, clicked through by hand in the AWS Console.

---

## Introduction

This is the hands-on follow-up to [6.1](../module-06.1-introduction-to-iam/README.md): create an IAM user, attach a managed policy to her, put two more users in a group, write a couple of custom policies, and create a role for an EC2 instance. Nothing here touches Terraform yet — that's next, once the console version of each concept is clear.

---

## Finding IAM

IAM sits under **Services → Security, Identity, & Compliance** (it's the first entry there), or I can just search for it from the console's search bar.

IAM is a **global service** — unlike EC2 or S3, where a resource only exists in the region I created it in, an IAM user, group, role, or policy exists once and is visible from every region in the account.

---

## Creating an IAM User: Lucy

**Users → Create user**, name her "Lucy". The wizard asks which kind of access to give her:

1. **Programmatic access** — issues an access key ID + secret access key, for the CLI, an SDK, or Terraform's AWS provider.
2. **AWS Management Console access** — a username + password to log into the web console.

> These aren't alternatives, they're complementary — I can give Lucy either, or both. This is the same "console access vs. programmatic access are separate credential types" point from 6.1.

For Lucy I set a custom console password and tick "require password reset on first login" — this automatically attaches an `IAMUserChangePassword` policy, which just lets her change her own password, nothing else. I skip permissions and tags for now and create the user.

After creation, the console offers a CSV download with her access key ID and secret access key. **This is the only time the secret key is ever shown** — if I lose it, the only fix is to deactivate that key and generate a new one, there's no "view secret again" option.

> AWS's guidance goes further than "download the CSV and keep it safe": it steers away from long-lived access keys on human IAM users entirely, pushing federated access through **IAM Identity Center** instead (the point [6.1](../module-06.1-introduction-to-iam/README.md) lands on). Many accounts warn — or block outright — on creating a new access key for a console user. Worth treating that access-key step as something to skip by default, not a routine part of creating a user.

---

## Attaching a Policy: AdministratorAccess on Lucy

On Lucy's **Permissions** tab, `IAMUserChangePassword` is already attached from account creation. I attach one more: `AdministratorAccess`, the broadest managed policy AWS ships —

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

`Action: *` on `Resource: *` — every action, on every resource. This is the same JSON I noted in 6.1, and this is exactly the "attach a permanent policy directly to a user" pattern from that lesson's decision framework — appropriate here only because the scenario says Lucy is the team lead who genuinely needs full account access, not a default I'd reach for.

---

## Groups: Abdul, Lee, and Project Sapphire Users

Creating a second user, Abdul, follows the same steps as Lucy. This time, instead of attaching a policy to him directly, I create a **group** during the wizard: "Project Sapphire Users", with `AmazonEC2FullAccess` attached and a tag `Name = Project Sapphire Users`.

Then I create a third user, Lee, and add him to that existing group instead of creating a new one. Abdul and Lee both now have full EC2 access — not because either of them has EC2 permissions attached individually, but because the group does.

I then attach `AmazonS3FullAccess` to the group as well. One attach, and both Abdul and Lee pick up S3 access at the same time. This is 6.1's "groups, for shared permissions" point, concretely: one attachment point instead of repeating the same policy on every user who needs it.

---

## Custom Policies: EC2-List-Read and S3-Read-Only

Managed policies (`AmazonEC2FullAccess`, `AdministratorAccess`, …) cover common cases; a **custom policy** is for something narrower AWS didn't already ship. To build one:

1. **Policies → Create Policy**
2. Pick a service — EC2 first.
3. Select only the actions I want — here, just the read/list ones, nothing that creates, modifies, or deletes.
4. Scope to all resources (for this demo).
5. Review and name it — `EC2-List-Read`.

Same steps again for S3, selecting only its read/list actions, named `S3-Read-Only`.

Once created, a custom policy behaves exactly like a managed one — it shows up in the same policy list and can be attached to a user, a group, or a role. This is 6.1's custom-policy example in practice: instead of `Action: "*"`, the JSON only lists the specific `Describe*`/`List*`/`Get*` actions I picked in the wizard.

---

## Creating a Role: EC2 → S3 Read-Only

An IAM user is for a person; a **role** is for an AWS service (or another account, or a federated identity) to *assume*. Here, the goal is: let an EC2 instance read from S3 without ever holding a static access key.

1. **Roles → Create Role**
2. Trusted entity type: **AWS Service**
3. Service that will use this role: **EC2**
4. Attach permissions: the custom `S3-Read-Only` policy from above.
5. Optional tag/description.
6. Name it — "S3-Read-Only Role" — and create.

That role is now available to attach to any EC2 instance. Once attached, the instance can call S3's read/list APIs using temporary, auto-rotated credentials — nothing gets stored as a long-lived key on the instance itself. This is 6.1's "IAM roles — permissions for AWS services, not people" section, built end to end: trusted entity → policy → role → attach to the resource that assumes it.

---

## Summary

- ✅ IAM lives under Security, Identity, & Compliance, and is global — one IAM object, visible in every region
- ✅ Created an IAM user (Lucy) with both console and programmatic access; her secret access key is visible only once, at creation
- ✅ Attached `AdministratorAccess` to her directly — the "permanent baseline policy on a user" pattern from 6.1
- ✅ Created a group (`Project Sapphire Users`) and attached `AmazonEC2FullAccess` + `AmazonS3FullAccess` to it once, instead of to each of Abdul and Lee individually
- ✅ Wrote two custom policies (`EC2-List-Read`, `S3-Read-Only`) scoped to specific read/list actions instead of `*`
- ✅ Created a role that trusts the EC2 service and carries `S3-Read-Only`, so an instance can assume it and get temporary S3 read access

---

## Key Takeaway

**Every concept from 6.1 has a console screen behind it: users hold credentials, policies (managed or custom) are the actual grant, groups share a policy across many users at once, and a role is what an AWS service assumes instead of holding a standing credential.**

- ✅ A user's console password and programmatic access key are separate, independently-issued credentials
- ✅ Attaching a policy to a group updates every member's effective permissions at once — no per-user repetition
- ✅ A custom policy is the same JSON shape as a managed one, just scoped to fewer actions
- ✅ A role only becomes useful once something (an EC2 instance, another account, a federated user) is set up to assume it
- ⚠️ AWS guidance favors IAM Identity Center for human access and reserves long-lived access keys for cases with no federation option, same conclusion [6.1](../module-06.1-introduction-to-iam/README.md) reaches

---

## Practice & Next Steps

In a sandbox AWS account, work through this same sequence by hand: one user with a directly-attached policy, one group shared by two users, one custom read-only policy, and one role an EC2 instance can assume. Then check what each identity can and can't do — try an action outside the attached policy and confirm it fails with `AccessDenied`.

Next up in Module 6: doing all of this through Terraform instead of the console — `aws_iam_user`, `aws_iam_group`, `aws_iam_policy`, and `aws_iam_role` as actual resource blocks.
