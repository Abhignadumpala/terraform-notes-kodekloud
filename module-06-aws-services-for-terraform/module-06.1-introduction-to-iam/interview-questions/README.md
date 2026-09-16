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

---

### Roles

**7. Why can't you just attach an IAM policy directly to an EC2 instance the way you would to a user?**
An EC2 instance isn't an IAM identity — it has no user of its own. Roles exist for this: a role is assumed by the service and grants temporary credentials, not permanent ones.

**8. What are some use cases for IAM roles beyond EC2-to-S3 access?**
Cross-account access, federated/external identity access (e.g. via an org's Active Directory), and any service-to-service permission grant.

---

### Scenario / Judgment

**9. A developer says a Terraform apply is failing with `AccessDenied` on `s3:PutObject`. What's your troubleshooting approach?**
Check which identity Terraform's AWS provider is actually using (user or assumed role), then check whether its attached policies allow that action on that specific bucket/resource — least privilege means the default is deny.

**10. Would you still create an individual IAM user with an access key for a new employee joining today?**
Current AWS best practice says no — use federation/IAM Identity Center (SSO) for human users with temporary credentials instead. IAM users with long-term access keys are now recommended only for specific cases (service accounts, exceptions) that federation doesn't cover.

**11. Why did AWS move away from recommending long-term access keys for people?**
Long-term keys don't expire on their own, so a leaked key stays valid indefinitely unless someone notices and rotates it. Temporary credentials (from federation or roles) expire automatically, shrinking the blast radius of a leak.
