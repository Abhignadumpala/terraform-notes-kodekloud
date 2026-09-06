# Module 04.2: Terraform State Considerations

I recently worked through Terraform state management and remote backends. When I first started with Terraform, I didn't think much about the `terraform.tfstate` file sitting in my project folder. Once I started thinking about working in a team, I realized state management is actually one of the more critical parts of running Terraform for real.

Most material I'd read up to this point (including the course this repo follows) teaches DynamoDB for state locking. But Terraform moves fast, and as of version 1.10+, it supports state locking natively through S3 — no DynamoDB table required. This note covers how state works, why a remote backend matters, and how to set one up using S3's native locking.

---

## Understanding Terraform State

Every time I run Terraform, it records what it created in a state file. By default, running Terraform in a folder creates a `terraform.tfstate` file right there in that same folder.

This file is a JSON record connecting what I wrote in my `.tf` code to what actually exists in AWS. When I create an EC2 instance, the state file records that my `aws_instance` resource corresponds to one specific, real instance in AWS (something like `i-0bc4bbe5b84387543`).

A simplified example:

```json
{
  "version": 4,
  "terraform_version": "1.2.3",
  "serial": 1,
  "resources": [
    {
      "mode": "managed",
      "type": "aws_instance",
      "name": "example",
      "instances": [{
        "attributes": {
          "ami": "ami-0fb653ca2d3203ac1",
          "id": "i-0bc4bbe5b84387543",
          "instance_state": "running",
          "instance_type": "t2.micro"
        }
      }]
    }
  ]
}
```

This mapping is what lets Terraform know what's already out there. Every time I run it again, it checks the current status of these resources and compares that to what my code wants — that comparison is how it figures out what to change.

---

## The Challenge: Working in a Team

Local state works fine solo. It falls apart once more than one person needs to touch the same infrastructure, for three reasons:

**1. Shared storage.** If everyone has their own local state file, everyone has a different idea of what's actually deployed. Everyone needs to be looking at the same file.

**2. Locking.** If two people run Terraform against the same state file at the same time, they can corrupt it — two processes racing to update the same file is exactly the kind of thing that causes chaos. Something needs to lock the file so only one person can write to it at a time.

**3. Isolating environments.** I want staging and production kept apart. If everything lives in one state file, a `plan` meant for staging can end up touching production by mistake.

### Why Not Just Put State in Git?

Since the `.tf` files already live in Git, my first thought was to commit `terraform.tfstate` there too. That doesn't hold up:

- **Manual, and easy to get wrong.** Nothing forces a `git pull` before `apply` or a `git push` after. Skip either one and someone eventually runs Terraform against a stale state, which can roll back real changes or duplicate resources. Not a matter of if, just when.
- **No locking.** Git has no concept of "this file is currently being written to by someone else's `apply`" — the concurrency problem is still there.
- **Security.** Terraform stores everything in plain text in the state file. Create a database with `aws_db_instance` and the username and password sit right there in the file. That's not something I want sitting in a Git repo where anyone with access can read it.

---

## Remote Backends: The Fix

A **backend** is just where Terraform stores its state. The default is the local backend — the file on disk I've been using. A remote backend stores that same file somewhere shared instead: Amazon S3, Azure Storage, Google Cloud Storage, or Terraform Cloud are the usual options. For an AWS setup, S3 is the obvious choice.

Here's how a remote backend fixes each problem from above:

- **Automatic state management.** Once a remote backend is configured, Terraform loads state from it before every `plan`/`apply` and saves it back after. No manual pulling or pushing.
- **Built-in locking.** With Terraform 1.10+, S3 handles locking natively. When I run `terraform apply`, Terraform creates a lock file in S3 (think of it like a bathroom door — first one there locks it, everyone else waits). If someone else already holds the lock, I can either let it fail immediately or add `-lock-timeout=10m` to wait up to 10 minutes for it to free up.
- **Better security.** S3 encrypts data both in transit and at rest, and IAM controls exactly who can read or write the state. Terraform still doesn't encrypt individual secrets *within* the state file itself, but this beats a plaintext file on a laptop by a wide margin.

---

## Why Amazon S3

For an AWS-based setup, S3 is the natural place to put state:

- **Fully managed** — no extra infrastructure to run.
- **Extremely durable and available** — Amazon designs it to essentially never lose a file (they quote "eleven nines" of durability).
- **Encryption built in** — at rest (AES-256) and in transit (TLS).
- **Native locking** — Terraform 1.10+ handles it directly, no DynamoDB table needed.
- **Versioning** — every revision of the state file is kept, so a bad apply is recoverable rather than a permanent loss.
- **Cheap** — this kind of usage fits comfortably inside the AWS Free Tier.

---

## Setting Up S3 as a Remote Backend

**1. Create the bucket.** Bucket names have to be globally unique across all of AWS, so I need a distinctive one, and I need to note both the name and region for later. A production bucket should also set `prevent_destroy` in its lifecycle block, so an accidental `terraform destroy` errors out instead of deleting the bucket the whole team's state lives in.

**2. Turn on versioning**, so every update to the state file keeps its previous version.

**3. Turn on server-side encryption**, so everything written to the bucket is encrypted by default.

**4. Block all public access.** S3 buckets are private by default, but it's easy to loosen that by accident — state holds sensitive data, so this is worth doing explicitly.

**5. Set the right IAM permissions.** Whoever (or whatever CI job) runs Terraform needs, at minimum:
- `s3:ListBucket` on the bucket
- `s3:GetObject` and `s3:PutObject` on the state file
- `s3:GetObject`, `s3:PutObject`, and `s3:DeleteObject` on the lock file (the state file's key with `.tflock` on the end)

**6. Point the backend block at the bucket:**

```hcl
terraform {
  backend "s3" {
    bucket       = "my-terraform-state-bucket"
    key          = "project/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
```

`use_lockfile = true` is the entire native-locking setup — no separate table, no separate resource. On an older Terraform version (before 1.10), the equivalent is a `dynamodb_table` parameter pointing at a DynamoDB table instead, but Terraform now prints a deprecation warning nudging me toward `use_lockfile`.

**7. Run `terraform init`.** It downloads providers, sets up the backend, and — if there's existing local state — asks whether to migrate it to the new backend.

**8. Verify it worked.** The state file should show up in the S3 console. Running `apply` shows Terraform acquiring and releasing the lock, and checking the bucket's version history shows a new version was saved.

I ran through this exact setup for real — actual bucket, actual EC2 instance, actual simulated lock conflict — in the [S3 Backend + Native State Locking hands-on lab](hands-on-lab/README.md).

### Securing State in S3

Short version of everything above: store state in S3 (not locally), encrypt it at rest, turn on versioning, block public access, lock IAM access down to just this bucket, and use locking (native S3, or DynamoDB on an older Terraform version) to stop concurrent writes.

---

## What Terraform Does Automatically After This

Once the backend is set up, Terraform handles all of this without me thinking about it:

- Pulls the latest state from S3 before any command runs
- Creates a lock file when it starts a state-changing operation
- Blocks any other operation that tries to run while the lock is held
- Pushes the updated state back to S3 once the command finishes
- Releases the lock when it's done
- Keeps a version of every single state change, so I can roll back if needed

With this in place, a team can work against the same infrastructure without stepping on each other or corrupting the state file.

---

## Migrating from DynamoDB to Native S3 Locking

For an existing setup that's still using `dynamodb_table`:

1. Upgrade to Terraform 1.10 or later.
2. Add `use_lockfile = true` to the backend block.
3. Test in a non-production environment first.
4. Run `terraform init` to reconfigure the backend.
5. Confirm locking still works with an `apply`.
6. Remove `dynamodb_table` once confident.
7. Delete the DynamoDB table itself, since nothing needs it anymore.

Both locking mechanisms can run at the same time during the migration, which gives a safety net while testing.

---

## Conclusion

Remote state is essential the moment more than one person touches the same infrastructure. Local state works for learning; it doesn't work for a team.

Terraform 1.10+'s native S3 locking removes the need for a DynamoDB table, which means less to set up and less to pay for. With encryption, versioning, and locking all turned on, state gets treated like the sensitive data it actually is — access controlled through IAM, with versioning as the way back if something goes wrong.

Starting a new project, I'd reach for native S3 locking from day one. For anything still on DynamoDB, migrating over is worth doing whenever there's room to.

---

## Related Notes

- [Hands-On Lab: S3 Backend + Native State Locking](hands-on-lab/README.md) — bootstrap the backend, migrate real state onto it, trigger and resolve a real lock conflict, then tear it all down
- [Module 04.0: Introduction to Terraform State](../module-04.0-introduction-to-terraform-state/)
- [Module 04.1: Purpose of State](../module-04.1-purpose-of-state/) — what the state file tracks and why
- [Experiment: What Happens If You Delete the State File?](../state-file-deletion-experiment/README.md) — what actually happens without a backup or a lock

## Official Resources

- [Terraform State Documentation](https://www.terraform.io/language/state)
- [Terraform S3 Backend Documentation](https://developer.hashicorp.com/terraform/language/backend/s3)
- [Sensitive Data in State](https://developer.hashicorp.com/terraform/language/state/sensitive-data)
