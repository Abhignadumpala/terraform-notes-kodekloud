# Interview Questions: S3

Based on [Module 6.5](../../module-06.5-introduction-to-s3/README.md) (S3 fundamentals) and [Module 6.6](../README.md) (S3 with Terraform), plus the [hands-on lab](../hands-on-lab/README.md) that actually ran into a couple of these.

---

### Fundamentals

**1. What's the difference between S3 and a block storage service like EBS?**
S3 is object storage — it stores whole files as opaque objects, with no filesystem underneath. EBS is block storage — it presents raw blocks an operating system can format and mount, which is what something like an EC2 instance's root volume needs. S3 is the right fit for "store this file, give it back later"; it's the wrong fit for "be the disk an OS boots from."

**2. What are the three parts of an S3 object?**
Key (its name/identifier within the bucket), data (the actual file content), and metadata (owner, size, last-modified timestamp, plus anything custom I attach).

**3. If I upload `pictures/cat.jpg`, is that a real folder structure in S3?**
No. Every object's key is flat — S3 has no real folder hierarchy underneath. `pictures/cat.jpg` is one object with a slash in its name; the console just renders keys with a shared prefix as if they were nested, for convenience.

**4. What are the S3 bucket naming rules?**
Lowercase letters, numbers, hyphens, and periods only — no uppercase, no underscores, must start and end with a letter or number, 3–63 characters. On top of that, names have to be unique — by default across every AWS account in the same partition, since AWS assigns each bucket a DNS name.

**5. Do S3 bucket names still have to be globally unique?**
By default, yes. But AWS added an opt-in **account regional namespace** in March 2026 — a bucket created that way only has to be unique within my own account and region, using a fixed name shape (`{prefix}-{account-id}-{region}-an`). It's a real, current alternative to the classic "someone already took this name" problem, not just a workaround like appending a random suffix.

**6. Is a new S3 bucket public or private by default?**
Private — only the bucket owner can reach it. Access has to be granted deliberately.

---

### Access Control

**7. What are the two ways to control access to an S3 bucket/object?**
Bucket policies (a JSON document attached to the whole bucket, same `Effect`/`Action`/`Resource`/`Principal` shape as an IAM policy) and Access Control Lists — ACLs (permissions attached to an individual object). Bucket policies are the current recommended path; new buckets have ACLs disabled by default since April 2023.

**8. Can an IAM group be used as the `Principal` in a bucket policy?**
No — bucket policies (and other resource-based policies) only accept individual users, roles, an AWS account, or an AWS service as a principal, never a group. This isn't theoretical — I hit it directly in the [hands-on lab](../hands-on-lab/README.md#4-the-bucket-policy): to grant a group's members access, the fix is to list each member's own ARN (e.g. via `data.aws_iam_group.*.users[*].arn`), not the group's ARN.

---

### Terraform Implementation

**9. Why are creating a bucket, uploading a file, and attaching a policy three separate Terraform resources instead of one?**
Same "existence ≠ permissions" pattern as IAM in [6.4](../../module-06.4-aws-iam-with-terraform/README.md) — `aws_s3_bucket` creates the container, `aws_s3_object` puts something inside it, and `aws_s3_bucket_policy` is what actually grants access. Creating the bucket alone gives nobody but the owner any access to it.

**10. What's the difference between `aws_s3_bucket_object` and `aws_s3_object`?**
`aws_s3_bucket_object` is the older resource — deprecated since AWS provider v4.0 (February 2022). `aws_s3_object` is the current one; new configs should use it.

**11. When uploading a file with `aws_s3_object`, what's the difference between `source` and `content`?**
`source` points at a local file path and uploads it directly from disk. `content` takes a literal string, or the result of `file("path")` if I want the contents of a text file. The distinction that matters: `file()` requires valid UTF-8 — it fails on binary files (like a `.doc` or an image), so `source` is the correct choice for anything that isn't plain text.

**12. Why use a `data "aws_iam_group"` block instead of just hardcoding a group's ARN into the bucket policy?**
A data source looks the group up at plan/apply time instead of me having to know and hardcode its ARN — useful because the group (and its members) might be managed elsewhere, outside this particular Terraform config, which is the realistic scenario the module note is modeling.

---

### Scenario / Judgment

**13. Your `aws_s3_bucket_policy` apply fails (or grants nobody access) even though the JSON looks right and references an IAM group's ARN as the principal. What's wrong?**
The principal is a group ARN, which AWS's resource-based policies reject. Fix: resolve it down to the group's individual member ARNs (e.g. `data.aws_iam_group.example.users[*].arn`) before putting it in `Principal.AWS`.

**14. `terraform apply` fails with `BucketAlreadyExists` on a name you're sure nobody in your own account has used. What's actually going on, and what are your options?**
S3 bucket names are unique across every AWS account by default, not just mine — someone else already owns that exact name. Options: pick a name that's guaranteed unique to me (e.g. append my account ID, which is what the [hands-on lab](../hands-on-lab/s3-bucket-code/s3_bucket.tf) does via `data.aws_caller_identity`), or opt into AWS's account regional namespace so uniqueness is scoped to my account instead of the whole platform.

**15. A bucket policy in a demo grants `"Action": "*"` to a group's members. Is that fine to leave as-is for a real environment?**
No — same least-privilege point as IAM. `"Action": "*"` is illustrative, granting full read/write/delete on every object in the bucket. A real policy would scope it down to just what the role actually needs, e.g. `["s3:GetObject", "s3:PutObject"]` for read/write without delete, or just `s3:GetObject` for pure read access.

**16. Where would you check whether a bucket policy actually took effect — on the IAM user's page, or the bucket's page?**
The bucket's page. A bucket policy is a *resource-based* policy — it's attached to the bucket, not the user, so it won't show up on the IAM user's own Permissions tab (that tab only shows identity-based policies attached directly to them). Check the S3 console → the bucket → **Permissions** tab → **Bucket policy**.
