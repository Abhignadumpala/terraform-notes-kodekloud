# Interview Questions: Introduction to IAM

Based on [Module 6.1](../README.md). Mix of fundamentals, policy mechanics, and the "what's changed" points from the current AWS docs.

---

### Fundamentals

**1. What's the difference between the AWS root account and an IAM user?**
Root has full unrestricted access and should only be used to create IAM users, then locked away. IAM users get scoped permissions.

**2. What are the two types of access an IAM user can have, and why are they separate?**
Console access (username/password, for the web UI) and programmatic access (access key ID + secret, for CLI/SDK/Terraform). They're separate credential types — console creds don't work for API calls and vice versa.

**3. What permissions does a brand-new IAM user have by default?**
None — least privilege by default. Permissions only come from policies attached to the user, a group, or a role.

---

### Policies & Permissions

**4. What's the difference between a managed policy and a custom policy?**
Managed policies (e.g. `AdministratorAccess`) are pre-built and maintained by AWS for common cases. Custom policies are JSON you write yourself to scope permissions to exactly what's needed.

**5. Walk through the structure of an IAM policy JSON document.**
`Version`, and a `Statement` array where each statement has `Effect` (Allow/Deny), `Action` (which API calls), and `Resource` (which resources it applies to).

**6. Why would you put users in an IAM group instead of attaching policies directly to each one?**
So permission changes happen in one place — attach/update policies on the group once instead of on every user individually.

**6a. What are the two types of IAM policies, and what's the difference?**
- **Identity-based policies** — attached to an identity: a user, a group, or a role. They define what that identity can do.
- **Resource-based policies** — attached directly to a resource instead of an identity (an S3 bucket policy, a Lambda function policy, an SQS queue policy, a KMS key policy, an IAM role's trust policy). They define who's allowed to reach that resource.

Not every service supports resource-based policies — S3, Lambda, SQS, DynamoDB, and KMS do, but plenty of services don't. **EC2 is a common one that doesn't** — there's no such thing as an "EC2 instance policy" attached to the instance itself; access to EC2 is controlled entirely through identity-based policies on whoever's calling the API.

**6b. What are the three types of identity-based policies?**
- **AWS managed policies** — created and maintained by AWS itself (`AdministratorAccess`, `AmazonS3ReadOnlyAccess`, etc.). I can attach them, but I can't edit them.
- **Customer managed policies** — policies I write and manage myself: standalone, reusable, attachable to multiple users/groups/roles. The `AdminUsers` and `S3ReadOnly` policies from [6.4](../../module-06.4-aws-iam-with-terraform/README.md) are both this type.
- **Inline policies** — embedded directly into one specific user, group, or role. Not reusable, not attachable to anything else, and deleted automatically if that identity is deleted.

**6c. What are the standard keywords in an IAM policy JSON document?**
- `Version` — the policy language version, almost always `"2012-10-17"`
- `Statement` — an array holding one or more individual permission statements
- `Effect` — `Allow` or `Deny`
- `Action` — which API call(s) the statement applies to, e.g. `s3:GetObject`
- `Resource` — which resource(s) the statement applies to, by ARN

Two more show up constantly once a policy gets more specific: `Principal` (who the statement applies to — required on resource-based policies, since there's no identity already attached the way there is on an identity-based policy) and `Condition` (extra constraints, like restricting by source IP or requiring MFA).

---

### Roles

**7. Why can't you just attach an IAM policy directly to an EC2 instance the way you would to a user?**
An EC2 instance isn't an IAM identity — it has no user of its own. Roles exist for this: a role is assumed by the service and grants temporary credentials, not permanent ones.

**8. What are some use cases for IAM roles beyond EC2-to-S3 access?**
Cross-account access, federated/external identity access (e.g. via an org's Active Directory), and any service-to-service permission grant.

**9. What's the difference between a policy and a role?**
A policy is just a JSON document defining permissions — `Effect`/`Action`/`Resource`, nothing more. A role is an identity that can be *assumed* (by a user, a service, another account) and has one or more policies attached to it. The policy defines what's allowed; the role is what gets the temporary credentials and carries that policy around. A policy on its own grants nothing until it's attached to a user, group, or role — and the same policy can attach to a user directly or to a role, with identical resulting permissions either way.

**9a. If a policy grants the same permissions either way, when do you attach it directly to a user vs. attach it to a role and assume that?**
It comes down to whether the caller can actually assume a role at all, and whether a permanent credential is really needed:
- **Direct attach to a user**, when there's no assume mechanism available — no AWS compute instance profile, no federated identity provider — such as a legacy tool that only supports static access keys, or a break-glass emergency account that must work even if SSO is down.
- **Assume a role**, when one is available — an EC2 instance or Lambda function (via an instance/execution role, credentials auto-injected and auto-rotated), cross-account access (the target account defines a role that trusts the source account, instead of creating a new user), or a human via federation (IAM Identity Center / a corporate IdP maps the person to a role for that session).

The reason roles are preferred whenever possible: their credentials are temporary and expire on their own, so a leaked one has a bounded window of usefulness. A user's access key has no such expiry — it's valid until someone notices and rotates or deletes it. Same permissions, very different blast radius if either one leaks.

---

### Scenario / Judgment

**10. A developer says a Terraform apply is failing with `AccessDenied` on `s3:PutObject`. What's your troubleshooting approach?**
Check which identity Terraform's AWS provider is actually using (user or assumed role), then check whether its attached policies allow that action on that specific bucket/resource — least privilege means the default is deny.

**11. Would you still create an individual IAM user with an access key for a new employee joining today?**
Current AWS best practice says no — use federation/IAM Identity Center (SSO) for human users with temporary credentials instead. IAM users with long-term access keys are now recommended only for specific cases (service accounts, exceptions) that federation doesn't cover.

**12. Why did AWS move away from recommending long-term access keys for people?**
Long-term keys don't expire on their own, so a leaked key stays valid indefinitely unless someone notices and rotates it. Temporary credentials (from federation or roles) expire automatically, shrinking the blast radius of a leak.

**13. In practice, would you give every employee a permanent policy directly, or route everything through roles?**
A common, reasonable pattern is both, for different purposes: attach one **permanent baseline policy** directly to each person, scoped to their day-to-day job (admin, read-only, developer, etc.), and use a **role** only for anything beyond that baseline — assumed just for the specific task, expiring once it's done. That's two separate decisions, not one: whether the baseline itself is permanent or temporary (a standing IAM user vs. a federated session through IAM Identity Center), and whether extra, task-specific permissions come from a role (yes, always). The fullest version of best practice makes *both* temporary — even the baseline comes from a federated session — but "permanent baseline + temporary role for extras" is still a real improvement over one person holding a single standing admin policy all the time.
