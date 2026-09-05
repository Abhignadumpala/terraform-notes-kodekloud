# Module 04.2: Terraform State Considerations

> This guide explores important considerations for managing Terraform state files, focusing on security best practices and differences between configuration files and state files.

Terraform state is the single source of truth for Terraform — it's how Terraform accurately syncs with whatever's actually deployed. In this note I look at what that means for security, and at the difference between my configuration files and the state file itself, since treating them the same way is a common (and risky) mistake.

---

## Table of Contents

1. [Local State vs. Remote State](#local-state-vs-remote-state)
2. [State Locking In Detail](#state-locking-in-detail)
3. [Sensitive Information in the State File](#sensitive-information-in-the-state-file)
4. [Terraform Configuration Files vs. State File](#terraform-configuration-files-vs-state-file)
5. [Editing the State File](#editing-the-state-file)
6. [Best Practices](#best-practices)

---

## Local State vs. Remote State

### What Is Local State?

By default, Terraform keeps state the simplest way it possibly can: a `terraform.tfstate` file sitting right next to my `.tf` files, on whatever machine I happened to run `apply` from.

```
BEFORE (Local):

My Laptop
└─ terraform.tfstate   (only I can see this)
```

That's fine for a solo experiment, and it's exactly what every lab in this repo has used up to this point. It stops being fine the moment more than one person or one machine needs to touch the same infrastructure.

**Problems with local state, concretely:**

- **Not shared.** A teammate running `terraform plan` on their own laptop has no idea my state exists. Terraform looks like it wants to recreate everything I already built, because as far as *their* copy of Terraform is concerned, nothing exists yet.
- **No locking.** Two people (or two CI jobs) running `apply` against the same infrastructure at the same time can each read the same "before" state, make conflicting changes, and the second one to finish silently overwrites the first one's state file. Nothing stops this locally — there's no lock to acquire.
- **A single point of failure.** If my laptop dies, gets wiped, or the file gets deleted, the state goes with it. Terraform still has no memory of what it built — same failure mode as the [state-file-deletion experiment](../state-file-deletion-experiment/README.md), just triggered by hardware instead of `rm`.
- **Sensitive data on one uncontrolled disk.** Whatever's in the state (see [Sensitive Information in the State File](#sensitive-information-in-the-state-file) below) is only as safe as that one laptop's disk encryption — no access logging, no IAM policy, nothing.

### What Is Remote State?

Remote state just means the same `terraform.tfstate` file lives somewhere shared and durable instead — an S3 bucket, Terraform Cloud, Azure Blob Storage, a GCS bucket — instead of a folder on one disk. Every `terraform` command reads and writes through that backend instead of the local file.

```
AFTER (Remote):

Cloud (AWS S3)
└─ terraform.tfstate   (my whole team, and CI, can all reach this)
```

**What moving to S3 specifically buys me** (this is the [`backend "s3"` hands-on lab](hands-on-lab/README.md) I actually ran):

- **Shared access** — anyone with the right IAM permissions gets the same, current state. No more "works on my machine" because my machine is the only one with the state file.
- **Versioning** — with S3 bucket versioning on, every write to `terraform.tfstate` keeps its prior version, so a bad apply's state is recoverable, not just overwritten forever.
- **Encryption at rest** — SSE on the bucket instead of whatever (if anything) my laptop's disk encryption is doing.
- **No local artifact to lose** — confirmed this directly in the lab: after pointing `app/` at the S3 backend, `ls` in that directory shows no `terraform.tfstate` at all. It's not there to lose.
- **The precondition for locking** — a shared backend is what makes state locking possible in the first place. Local state has nowhere to hold a lock; a shared backend does.

Remote state on its own solves *access* and *durability*. It doesn't, by itself, stop two people writing at once — that's what locking is for.

---

## State Locking In Detail

### What a Lock Actually Protects Against

Picture two people running `terraform apply` against the exact same remote state, seconds apart, with no locking in place:

1. Both read the *same* current state as their starting point.
2. Both compute a plan based on that same starting point.
3. Person A finishes first and writes their new state.
4. Person B finishes second and writes *their* new state — silently overwriting whatever Person A just did, because Person B's plan was never aware Person A's change happened.

Nothing in that sequence raises an error. The state file just quietly loses Person A's change, and Terraform's internal record of "what's really deployed" is now wrong. That's the failure state locking exists to prevent.

### How It Works With S3 + DynamoDB

Before Terraform writes state, it first tries to acquire a lock by writing a lock item to a DynamoDB table, keyed on `LockID` — which is just `<bucket>/<key>` for that specific state file. That write is a **conditional put**: it only succeeds if no lock item already exists for that `LockID`.

- **No existing lock** → the put succeeds, Terraform proceeds with `plan`/`apply`, and deletes the lock item when it's done.
- **A lock already exists** → the conditional put fails, and Terraform refuses to continue at all — it doesn't queue, wait, or retry. It just stops and tells me who (supposedly) holds the lock, what operation they're running, and when it started.

I confirmed this exact mechanic myself in the [S3 + DynamoDB locking lab](hands-on-lab/README.md) by writing a fake lock item straight into the table and then running `terraform plan`:

```
Error: Error acquiring the state lock

Lock Info:
  ID:        fake-lock-id
  Operation: OperationTypeApply
  Who:       someone-else@another-machine

Terraform acquires a state lock to protect the state from being written
by multiple users at the same time. Please resolve the issue above and
try again.
```

Terraform didn't try to be clever about merging or waiting — it just stopped, exactly as it would have if a real teammate's `apply` were genuinely still running.

### Resolving a Stuck Lock

A lock normally clears itself the moment the operation holding it finishes. It only stays stuck if that operation crashed, got killed, or (like my lab) was never real to begin with. Two ways to clear it:

```bash
# Tell Terraform to release it (records who force-unlocked, for the record)
terraform force-unlock <LOCK_ID>

# Or remove the DynamoDB item directly - what force-unlock does under the hood
aws dynamodb delete-item \
  --table-name terraform-state-locks \
  --key '{"LockID": {"S": "<bucket>/<key>"}}'
```

`force-unlock` should only ever be used once I'm actually certain no other operation is genuinely still running against that state — using it to bypass a *real* lock defeats the entire point of having one.

### A Note on Newer Terraform Versions

Running through the lab, `terraform init` printed a deprecation warning I hadn't expected:

```
Warning: Deprecated Parameter
  The parameter "dynamodb_table" is deprecated. Use parameter "use_lockfile" instead.
```

Recent Terraform versions can do S3 native locking via a lockfile object in the same bucket (`use_lockfile = true`), without a separate DynamoDB table at all. `dynamodb_table` still works — it's the classic mechanism, and what this lab deliberately used to see the lock-and-DynamoDB relationship directly — but it's worth knowing the newer option exists for anything built going forward.

---

## Sensitive Information in the State File

Terraform state files contain **detailed information about your infrastructure, including sensitive data**. When using local state, all of that is stored in a **plaintext JSON file** — nothing in it is encrypted or masked. That makes securing this file just as important as securing any other credential.

### What Sensitive Data Is Stored?

Take a single AWS EC2 instance. The state file for it stores:

- AMI ID (`ami-0a634ae95e11c6f91`)
- Instance type (`t2.micro`)
- Private IP (`172.31.7.21`)
- Public IP (`54.71.34.19`)
- Security group IDs
- SSH key pair names
- Subnet information
- Network interface IDs
- Block device mappings
- ...and more

### Real Example: AWS EC2 Instance State File

```json
{
  "mode": "managed",
  "type": "aws_instance",
  "name": "dev-ec2",
  "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
  "instances": [
    {
      "schema_version": 1,
      "attributes": {
        "ami": "ami-0a634ae95e11c6f91",
        "instance_type": "t2.micro",
        "key_name": "my-ssh-key",
        "primary_network_interface_id": "eni-0ccd57b1597e633e0",
        "private_dns": "ip-172-31-7-21.us-west-2.compute.internal",
        "private_ip": "172.31.7.21",
        "public_dns": "ec2-54-71-34-19.us-west-2.amazonaws.com",
        "public_ip": "54.71.34.19",
        "security_groups": [
          "default",
          "web-sg"
        ],
        "subnet_id": "subnet-0a1b2c3d4e5f6g7h8",
        "vpc_security_group_ids": [
          "sg-0123456789abcdef0"
        ]
      },
      "root_block_device": [
        {
          "delete_on_termination": true,
          "device_name": "/dev/sda1",
          "encrypted": false,
          "iops": 100,
          "volume_id": "vol-070720a3636979c22",
          "volume_size": 8,
          "volume_type": "gp2"
        }
      ]
    }
  ]
}
```

An EC2 instance is one of the tamer examples. Some resource types put outright secrets in state:

**AWS RDS database:**
```json
{
  "type": "aws_db_instance",
  "attributes": {
    "db_instance_identifier": "production-database",
    "master_username": "admin",
    "master_password": "MySecurePassword123!",
    "allocated_storage": 20,
    "engine": "mysql",
    "endpoint": "prod-db.c9akciq32.us-east-1.rds.amazonaws.com"
  }
}
```
`master_password` is sitting there in plaintext.

**AWS Secrets Manager secret:**
```json
{
  "type": "aws_secretsmanager_secret_version",
  "attributes": {
    "secret_id": "prod/api-key",
    "secret_string": "{\"api_key\": \"sk_live_abc123xyz...\"}"
  }
}
```
The whole point of Secrets Manager is to keep this out of plaintext — but Terraform's own state file undoes that if it's not secured.

**AWS IAM access key:**
```json
{
  "type": "aws_iam_access_key",
  "attributes": {
    "user": "terraform-user",
    "id": "AKIAIOSFODNN7EXAMPLE",
    "secret": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
  }
}
```
That `secret` field is a live, usable AWS credential.

### Security Risk: What Could Happen?

Three realistic ways this goes wrong:

1. **State file committed to a public (or later-made-public) Git repo.** Anyone who can read the repo can read `terraform.tfstate`, which means they can read every credential and IP address above — and use them.
2. **State file left unencrypted on a laptop.** If the laptop is lost or stolen, whoever has it can open the file in a text editor and read out the same data.
3. **State file stored in S3 with the wrong bucket permissions.** If the bucket isn't locked down, the file becomes downloadable by anyone who finds it, exposing the whole infrastructure at once.

In every case, the actual damage isn't "someone saw my Terraform code" — it's "someone now has working AWS credentials."

### Protection Strategies

- Never commit `terraform.tfstate` to Git
- Add state files to `.gitignore`
- Store state remotely (S3, Terraform Cloud) instead of locally
- Enable encryption for remote state
- Use state locking to prevent concurrent writes
- Restrict IAM access to wherever state is stored
- Encrypt the disk if you do keep state locally
- Never send a state file over email or chat

---

## Terraform Configuration Files vs. State File

My working directory contains two fundamentally different kinds of files, and it's easy to treat them the same way by habit — which is exactly what causes state to end up in Git by accident.

### 1. Terraform Configuration Files (HCL)

These are written in HashiCorp Configuration Language. This is my **infrastructure code** — safe to commit, safe to share.

```hcl
# main.tf - Configuration file (safe for Git)

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

# Create Security Group
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create EC2 Instance
resource "aws_instance" "web" {
  ami                    = "ami-0c55b159cbfafe1f0"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web.id]
  subnet_id              = aws_subnet.main.id

  tags = {
    Name = "web-server"
  }
}

# Create RDS Database
resource "aws_db_instance" "prod" {
  allocated_storage   = 20
  engine              = "mysql"
  engine_version      = "8.0.35"
  instance_class      = "db.t2.micro"
  identifier          = "prod-database"
  username            = var.db_username     # variable, not hardcoded
  password            = var.db_password     # variable, not hardcoded
  skip_final_snapshot = false

  tags = {
    Name = "production-db"
  }
}
```

**Characteristics:**
- Written in HCL, readable by a human
- Describes what I want, not what already exists
- Version controllable — same file for every developer
- No sensitive data hardcoded (uses `var.db_username` / `var.db_password` instead)
- Reusable and shareable

### 2. Terraform State File (JSON)

This is the **runtime record** of what's actually deployed — generated by Terraform, not written by me.

```json
{
  "version": 4,
  "terraform_version": "1.5.0",
  "serial": 3,
  "lineage": "unique-id-12345",
  "resources": [
    {
      "type": "aws_vpc",
      "name": "main",
      "instances": [
        {
          "attributes": {
            "id": "vpc-0a1b2c3d4e5f6g7h8",
            "cidr_block": "10.0.0.0/16",
            "enable_dns_hostnames": true
          }
        }
      ]
    },
    {
      "type": "aws_security_group",
      "name": "web",
      "instances": [
        {
          "attributes": {
            "id": "sg-0123456789abcdef0",
            "name": "web-sg",
            "vpc_id": "vpc-0a1b2c3d4e5f6g7h8"
          }
        }
      ]
    },
    {
      "type": "aws_instance",
      "name": "web",
      "instances": [
        {
          "attributes": {
            "id": "i-0a1b2c3d4e5f6g7h8",
            "ami": "ami-0c55b159cbfafe1f0",
            "instance_type": "t2.micro",
            "public_ip": "54.71.34.19",
            "private_ip": "10.0.1.50",
            "security_groups": ["sg-0123456789abcdef0"]
          }
        }
      ]
    }
  ]
}
```

**Characteristics:**
- JSON, not really meant for a human to read
- Shows what actually exists right now
- Contains real resource ids and real data, not placeholders
- Should never go into version control — it has sensitive data
- Different per environment (dev state ≠ prod state)

### Side-by-Side Comparison

| Aspect | Configuration Files (HCL) | State File (JSON) |
|--------|---------------------------|-------------------|
| **Format** | HashiCorp Configuration Language | JSON |
| **Purpose** | Define what to create | Track what exists |
| **Content** | Code / template | Real resource ids & data |
| **Sensitive data** | No — uses variables | Yes — plaintext |
| **Version control** | Yes — store in Git | No — store remotely |
| **Across developers** | Same for everyone | Different per environment |
| **Typical location** | GitHub, GitLab | AWS S3, Terraform Cloud |

### Workflow: Config Files vs. State File

```
Developer's machine (Git repository):
  main.tf                     — version controlled
  variables.tf                — shared
  outputs.tf                  — shared
  terraform.tfstate           — never in Git
  terraform.tfstate.backup    — never in Git

Remote storage (AWS S3):
  terraform.tfstate           — encrypted and access-controlled
  terraform.tfstate.backup    — encrypted and access-controlled
```

### Why This Separation?

**Configuration files (HCL):**
- Same across all developers
- Describes intent, not current reality
- No secrets hardcoded
- Belongs in version control

**State file (JSON):**
- Different per environment
- Contains actual AWS resource ids
- Contains sensitive data
- Belongs in centralized, secured storage — not Git

---

## Editing the State File

> **Critical warning:** the Terraform state file is a JSON data structure meant exclusively for Terraform's own internal use. Editing it by hand is strongly discouraged.

**Why not just open it and edit it directly?**

A stray character breaks the JSON. A wrong id breaks a dependency Terraform was relying on. Either way, Terraform can end up unable to parse the file, or worse, applying against a state that no longer matches what it thinks it manages — and untangling that by hand is much harder than the edit that caused it.

**The safe alternative is Terraform's own `state` subcommands** — they validate what they're doing, keep the state file's structure intact, and (for the most part) can be reasoned about or undone.

### 1. List All Resources in State

```bash
terraform state list
```

```
aws_vpc.main
aws_security_group.web
aws_instance.web_server
aws_db_instance.prod
```

### 2. Remove a Resource from State

```bash
terraform state rm aws_instance.web_server
```

The instance keeps running in AWS — Terraform just stops tracking and managing it.

### 3. Rename a Resource

```bash
terraform state mv aws_instance.web_server aws_instance.production_server
```

My code now needs to reference the new name, `aws_instance.production_server`, going forward.

### 4. Import an Existing AWS Resource into State

```bash
terraform import aws_instance.web_server i-0a1b2c3d4e5f6g7h8
```

Terraform starts managing a resource that already existed in AWS but wasn't in state before.

### What Actually Happens If the State File Is Gone

I tested this instead of just taking it on faith: deleted `terraform.tfstate` for a running instance and ran `terraform plan`. It did **not** show drift — with no state to compare against, Terraform just proposed a plain `+ create`, identical to a first-ever apply. Running `apply` after that built a second, real instance and left the original one running but orphaned. Confirmed the flip side too: `terraform destroy` only ever touched the tracked instance, never the orphan — and `terraform import` was what it took to bring the orphan back under management before a second `destroy` could finally remove it. Full write-up: [Experiment: What Happens If You Delete the State File?](../state-file-deletion-experiment/README.md)

---

## Best Practices

### Configuration Files (HCL)

- Store in a Git repository (GitHub, GitLab, etc.)
- Use meaningful variable and resource names
- Comment anything non-obvious
- Use variables for sensitive values — never hardcode them
- Use modules for reusable code
- Tag resources consistently
- Document the infrastructure as you go

### State Files

- Store in a secure remote backend (S3, Terraform Cloud)
- Enable encryption for remote state
- Enable versioning (e.g. S3 bucket versioning)
- Restrict IAM access to the state storage
- Use state locking to prevent concurrent writes
- Never commit to Git
- Add `terraform.tfstate` to `.gitignore`
- Back up state files regularly

### `.gitignore` Example

```bash
# Never commit state files
terraform.tfstate
terraform.tfstate.*
terraform.tfstate.backup

# Other local files
.terraform/
.terraform.lock.hcl
*.tfvars
*.tfvars.json
crash.log
override.tf
override.tf.json
*.override.tf
*.override.tf.json
```

### Securing State in S3

If I'm using AWS S3 as the remote backend, the security measures that matter most are:

- Store state in S3, not on a local machine
- Enable encryption at rest
- Enable versioning for recovery
- Block all public access on the bucket
- Use state locking (DynamoDB) to prevent conflicting writes
- Restrict IAM access to just the state bucket

> 🧪 **Hands-on lab:** [S3 Backend + DynamoDB State Locking](hands-on-lab/README.md) — stand up the S3 bucket and DynamoDB lock table, migrate a real EC2 instance's state onto them, then simulate a held lock and watch `terraform plan` refuse to run until it's resolved.

---

## Summary

Managing Terraform state comes down to a few security-minded habits:

- **Local state doesn't scale past one person** — no sharing, no locking, no recovery if the laptop is gone
- **Remote state (e.g. S3) fixes access and durability** — locking (e.g. DynamoDB) is the separate piece that fixes concurrent writes
- **State holds sensitive data** — plaintext passwords, IP addresses, API keys, and credentials, not just resource ids
- **Never commit state to Git** — always use a remote backend (S3, Terraform Cloud) instead
- **Keep config and state separate** — HCL goes in Git; state goes in secured remote storage
- **Use `terraform state` commands, not manual edits** — `list`, `rm`, `mv`, `import` instead of opening the JSON directly
- **Turn on encryption, versioning, access controls, and locking** wherever state actually lives
- **Back up state regularly** — it's the one file that's genuinely hard to reconstruct if it's lost

Getting these right is what keeps Terraform's biggest convenience — one file that knows everything about your infrastructure — from also being its biggest liability.

---

## Related Notes

- [Module 04.0: Introduction to Terraform State](../module-04.0-introduction-to-terraform-state/) — the hands-on lab
- [Module 04.1: Purpose of State](../module-04.1-purpose-of-state/) — what the state file tracks and why
- [Experiment: What Happens If You Delete the State File?](../state-file-deletion-experiment/README.md) — deleted state on a live instance to see whether Terraform shows drift or just recreates it (spoiler: recreates, and orphans the original), then tested whether `destroy` reaches the orphan too and used `import` to bring it back under management
- [Hands-On Lab: S3 Backend + DynamoDB State Locking](hands-on-lab/README.md) — remote state and locking, in practice rather than in theory

## Official Resources

- [Terraform State Documentation](https://www.terraform.io/language/state)
- [Sensitive Data in State](https://developer.hashicorp.com/terraform/language/state/sensitive-data)
- [Terraform `state` CLI Commands](https://www.terraform.io/cli/commands/state)
