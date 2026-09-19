# 📘 Module 6.5: Introduction to AWS S3

> Every S3 backend I've used since [4.1](../../module-04-terraform-state/module-04.1-purpose-of-state/README.md) has quietly assumed a bucket exists and my credentials can write to it. This is the module that actually explains what's on the other end of that `backend "s3" { bucket = ... }` block.

---

## Introduction

S3 (Simple Storage Service) is AWS's object storage service — built to hold an effectively unlimited number of files (documents, images, videos, Terraform state files, anything) reliably and at scale. It's **object storage**, not **block storage**: S3 stores whole files as opaque objects, it doesn't manage filesystem blocks the way an EC2 instance's root volume (EBS) does. That distinction is why S3 is the right fit for "store this file and give it back to me later" and the wrong fit for "be the disk an operating system boots from."

This is the third stop in Module 6, after [6.1](../module-06.1-introduction-to-iam/README.md) (IAM concepts), [6.2](../module-06.2-demo-iam/README.md) (IAM in the console), [6.3](../module-06.3-programmatic-access/README.md) (programmatic access), and [6.4](../module-06.4-aws-iam-with-terraform/README.md) (IAM in Terraform) — S3 is the other AWS service the state-backend notes have been leaning on this whole time.

---

## Buckets and Objects

S3 organizes everything into **buckets** — top-level containers, one per use case or project. Inside a bucket, every file I upload is an **object**. That holds true even when the key *looks* like a folder path: `pictures/cat.jpg` and `videos/dog.mp4` are two flat objects with slash-containing names, not files inside real subdirectories. S3 has no actual folder hierarchy underneath — the console just renders keys with a common prefix as if they were nested, for convenience.

![Table of five objects in the all-pets bucket — pets.json, dog.jpg, cat.mp4, pictures/cat.jpg, videos/dog.mp4 — each with its own https://all-pets.us-west-1.amazonaws.com/... address](images/01-s3-object-listing-table.jpg)

### Bucket Naming Rules

- **DNS-compliant**: lowercase letters, numbers, hyphens, and periods only — no uppercase, no underscores, must start and end with a letter or number.
- **3 to 63 characters** long.
- **Unique** — but *where* it has to be unique depends on which namespace I create it in (below).

Full rules (there are a few more edge cases — no IP-address-shaped names, no leading `xn--`, a handful of reserved prefixes/suffixes for AWS's own features) are in the [official bucket naming documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucketnamingrules.html), the source of truth for this.

### Two Namespaces: Shared Global vs. Account Regional

A plain bucket create (`aws s3 mb`, or the default `aws_s3_bucket` in Terraform) lands in S3's **shared global namespace** — the name has to be unique across every AWS account in the same partition, forever, the same way a domain name does. This is why bucket names have historically needed random suffixes tacked on: someone else may have already taken the plain name I wanted, and there's no way to know except trying.

AWS also offers an **account regional namespace**: an opt-in way to create a bucket whose name only has to be unique *within my own account and region*, not across every AWS customer. The name has to follow a fixed shape — `{my-chosen-prefix}-{12-digit-account-id}-{region}-an` (e.g. `reports-111122223333-us-west-2-an`) — and the create-bucket call has to explicitly opt in (`aws s3api create-bucket --bucket ... --bucket-namespace account-regional`, or `x-amz-bucket-namespace: account-regional` at the API level). AWS recommends this path for new buckets specifically because a name I want is never unavailable due to another account having grabbed it first — full details in [Namespaces for general purpose buckets](https://docs.aws.amazon.com/AmazonS3/latest/userguide/gpbucketnamespaces.html).

### Accessing a Bucket by URL

Once created, a bucket's virtual-hosted–style endpoint is `https://<bucket_name>.s3.<region>.amazonaws.com` — e.g. a bucket named `all-pets` in US West (N. California) is reachable at `https://all-pets.s3.us-west-1.amazonaws.com`. Objects inside it are addressed by appending the object's key: `https://all-pets.s3.us-west-1.amazonaws.com/dog.jpg`.

### File Size

A single object can be up to **5 TB**. What the slide doesn't mention: a single `PUT` request tops out at **5 GB** — anything bigger than that has to go through S3's **multipart upload** (splitting the file into parts, uploading them in parallel, then S3 reassembles them). The `aws s3 cp`/`aws s3 sync` CLI commands and most SDKs do this automatically once a file crosses that threshold; it only becomes something I'd think about directly if I were calling the raw `PutObject` API myself.

---

## Object Structure

Every S3 object is really three things bundled together:

- **Key** — the object's unique name within the bucket (`dog.jpg`, or `pictures/cat.jpg`)
- **Data** — the actual file content
- **Metadata** — extra info AWS tracks automatically (owner, size, last-modified timestamp) plus anything custom I attach myself

![dog.jpg inside the all-pets bucket, shown as Key=dog.jpg / Value=Data (the object data) plus Metadata: Owner=Lucy, Size=5MB, Last Modified=Jan 26 2020](images/02-s3-object-metadata.jpg)

---

## Access Control

New buckets and objects are **private by default** — only the bucket owner (the AWS account, really) can reach them. AWS gives two mechanisms to open that up deliberately:

- **Bucket policies** — a JSON document attached to the whole bucket, same `Effect`/`Action`/`Resource`/`Principal` shape as an IAM policy. Scoped at the bucket (or bucket+prefix) level. This is the current recommended path for controlling access.
- **Access Control Lists (ACLs)** — permissions attached to an individual object. New buckets have ACLs disabled by default (the "Bucket owner enforced" [Object Ownership](https://docs.aws.amazon.com/AmazonS3/latest/userguide/about-object-ownership.html) setting) — ACLs only come into play for buckets created before that default existed, or a narrow set of cases like certain cross-account log-delivery setups that still require them.

![all-pets bucket containing dog.jpg, with a padlock on the object (ACLs) and a padlock on the whole bucket (Bucket Policies)](images/03-s3-access-control-acl-policy.jpg)

### Example: A Bucket Policy Granting Read Access

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:GetObject"
            ],
            "Effect": "Allow",
            "Resource": "arn:aws:s3:::all-pets/*",
            "Principal": {
                "AWS": [
                    "arn:aws:iam::123456123457:user/Lucy"
                ]
            }
        }
    ]
}
```

This grants IAM user Lucy (identified by her full ARN in `Principal`) `s3:GetObject` on every object in `all-pets` (`/*`). Same policy shape works for public access too — drop the `Principal` restriction to `"*"` — which is exactly why bucket policies need care: a wrong `Resource`/`Principal` combination can expose a bucket to the entire internet instead of one user.

> ⚠️ Same warning as [6.1](../module-06.1-introduction-to-iam/README.md#assigning-permissions) — least privilege applies here too. Don't reach for public or account-wide access when a scoped `Principal`/`Resource` does the job.

---

## Summary

- ✅ S3 is object storage — whole files as objects, not filesystem blocks like EBS
- ✅ Buckets hold objects; bucket names are DNS-compliant (lowercase, no underscores, 3–63 chars, no trailing hyphen) and, by default, globally unique — though an opt-in **account regional namespace** (since March 2026) can scope uniqueness to just my own account+region instead
- ✅ "Folders" in the console are cosmetic — every object's key is flat, even one that looks like `pictures/cat.jpg`
- ✅ Max object size is 5 TB; a single `PUT` is capped at 5 GB, past that it's multipart upload
- ✅ An object = key + data + metadata (owner, size, last-modified, plus anything custom)
- ✅ Private by default; bucket policies (JSON, bucket-wide) and ACLs (per-object) are the two access-control mechanisms — though ACLs are off by default on new buckets since 2023, bucket/IAM policies are the current recommended path

---

## Key Takeaway

**S3 stores flat objects in uniquely-named buckets, locked down to the account owner until a bucket policy (or IAM policy) says otherwise.**

- ✅ Object storage, not block storage — files in, files out, no filesystem semantics
- ✅ Bucket names live in a DNS namespace shared by every AWS customer by default — but since March 2026, an account regional namespace is available so a name only has to be unique to my own account
- ⚠️ "Folders" are a UI illusion over flat, prefix-named keys
- ⚠️ Default-private, and ACLs are increasingly a legacy path — bucket policies (and IAM policies on the caller) are the mechanism to reach for now

---

## Practice & Next Steps

In the console (or a sandbox account), create a bucket with a name that violates one of the naming rules (uppercase letters, or a trailing hyphen) and confirm AWS rejects it outright. Then create a valid bucket, upload a small file, and try to fetch its object URL directly while the bucket is still private — confirm it 403s — before writing a bucket policy scoped to just that one object's key and watching the same URL start working.

Next up in Module 6: wiring S3 into Terraform itself — `aws_s3_bucket` and the policy/ACL resources that go with it, the same way [6.4](../module-06.4-aws-iam-with-terraform/README.md) did for IAM users and policies.
