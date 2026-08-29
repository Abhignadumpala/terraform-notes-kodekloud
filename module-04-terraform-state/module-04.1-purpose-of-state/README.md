# Module 04.1: Purpose of State

> This article explores the role of the state file in Terraform and how it maps resource configurations to real-world AWS infrastructure.

In this note I dig into what the state file is actually doing for me — how it maps my resource configuration to the real infrastructure Terraform manages. Whether it's an EC2 instance, an S3 bucket, a security group, or a data source lookup, every resource's unique identity and metadata (including its dependencies) gets recorded in this one file. That record is what lets Terraform generate an accurate plan whenever there's drift between my configuration and what's actually out there. Most of the examples below reuse the real resource ids from the [Module 04.0](../module-04.0-introduction-to-terraform-state/) lab.

---

## Table of Contents

1. [Managed Resources vs Data Sources](#managed-resources-vs-data-sources)
2. [Managing Resource Dependencies](#managing-resource-dependencies)
3. [Performance Gains with State Caching](#performance-gains-with-state-caching)
4. [Enhancing Team Collaboration with Remote State](#enhancing-team-collaboration-with-remote-state)

---

## Managed Resources vs Data Sources

Terraform tracks two types of resources in the state file, each serving a different purpose:

### Managed Resources: `"mode": "managed"`

Managed resources are infrastructure components that Terraform **creates, owns, and manages**. When I define one of these, Terraform takes full responsibility for it.

**Example AWS managed resources:**

```hcl
# Terraform creates this security group
resource "aws_security_group" "web_sg" {
  name        = "web-security-group"
  description = "Security group for web server"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Terraform creates this EC2 instance
resource "aws_instance" "web_server" {
  ami                    = "ami-12345"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name = "my-web-server"
  }
}

# Terraform creates this IAM role
resource "aws_iam_role" "app_role" {
  name = "app-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}
```

**State file representation (managed):**

```json
{
  "mode": "managed",
  "type": "aws_instance",
  "name": "web_server",
  "instances": [
    {
      "attributes": {
        "id": "i-077f37d5b08506306",
        "instance_type": "t2.micro",
        "ami": "ami-12345",
        "vpc_security_group_ids": ["sg-03ee8ffc10cd43d96"]
      }
    }
  ]
}
```

### Data Sources: `"mode": "data"`

Data sources are **references to existing infrastructure** that Terraform reads but doesn't create. They let me query AWS for information without taking ownership of the resource itself.

**Example AWS data sources:**

```hcl
# Terraform finds the latest Amazon Linux 2 AMI (doesn't create it)
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Terraform reads the default VPC (doesn't create it)
data "aws_vpc" "default" {
  default = true
}

# Terraform reads available availability zones (doesn't create them)
data "aws_availability_zones" "available" {
  state = "available"
}

# Terraform reads an existing security group
data "aws_security_group" "default_sg" {
  name   = "default"
  vpc_id = data.aws_vpc.default.id
}
```

**State file representation (data source):**

```json
{
  "mode": "data",
  "type": "aws_ami",
  "name": "amazon_linux_2",
  "instances": [
    {
      "attributes": {
        "id": "ami-0c3a3c65a049b6922",
        "most_recent": true,
        "owner_id": "137112412989"
      }
    }
  ]
}
```

### Key Difference

| Aspect | Managed Resource | Data Source |
|--------|------------------|------------|
| **Created by** | Terraform | Already exists in AWS |
| **Stored in state** | Yes — to track ownership | Yes — to cache the lookup |
| **Terraform deletes on destroy** | Yes | No |
| **Re-queried every apply** | No — uses refresh | Yes — uses reading |
| **Why in state** | Track what Terraform created | Cache the lookup result |

### Reading vs Refreshing

**Managed resources use "Refreshing state":**
```bash
aws_security_group.web_sg: Refreshing state... [id=sg-03ee8ffc10cd43d96]
aws_instance.web_server: Refreshing state... [id=i-077f37d5b08506306]
```
- Terraform already knows the resource id
- It just verifies the resource still exists
- **Fast** — it trusts state

**Data sources use "Reading":**
```bash
data.aws_ami.amazon_linux_2: Reading...
data.aws_availability_zones.available: Reading...
```
- Terraform re-queries AWS
- It fetches current values, not yesterday's values
- **Slower** — it has to ask AWS every time

---

## Managing Resource Dependencies

Terraform supports two types of dependencies: **implicit** and **explicit**. Understanding how state tracks these is what makes correct create/destroy ordering possible.

### Implicit Dependencies (From References)

When a resource references another resource, Terraform automatically creates a dependency:

```hcl
# IAM role
resource "aws_iam_role" "ec2_role" {
  name = "ec2-web-server-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Instance profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-web-server-profile"
  role = aws_iam_role.ec2_role.name  # DEPENDENCY!
}

# Security group
resource "aws_security_group" "web_sg" {
  name        = "web-security-group"
  description = "Security group"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 instance references both the profile and the security group
resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name  # DEPENDENCY!
  vpc_security_group_ids = [aws_security_group.web_sg.id]             # DEPENDENCY!
}
```

**Applying this configuration, Terraform creates resources in this order:**

```bash
$ terraform apply

Plan: 5 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Enter a value: yes

aws_iam_role.ec2_role: Creating...
aws_security_group.web_sg: Creating...
aws_iam_role.ec2_role: Creation complete after 1s [id=ec2-web-server-role]
aws_security_group.web_sg: Creation complete after 10s [id=sg-03ee8ffc10cd43d96]

aws_iam_instance_profile.ec2_profile: Creating...
aws_iam_instance_profile.ec2_profile: Creation complete after 7s [id=ec2-web-server-profile]

aws_instance.web_server: Creating...
aws_instance.web_server: Still creating... [10s elapsed]
aws_instance.web_server: Creation complete after 16s [id=i-077f37d5b08506306]

Apply complete! Resources: 5 added, 0 changed, 0 destroyed.
```

**Why this order?**
1. `aws_iam_role` and `aws_security_group` have no dependencies on each other, so they're created in parallel.
2. `aws_iam_instance_profile` depends on `aws_iam_role`, so it waits for the role to finish first.
3. `aws_instance` depends on both the profile and the security group, so it's created last.

### State File Tracks Dependencies

```json
{
  "type": "aws_instance",
  "name": "web_server",
  "instances": [
    {
      "attributes": {
        "id": "i-077f37d5b08506306",
        "iam_instance_profile": "ec2-web-server-profile",
        "vpc_security_group_ids": ["sg-03ee8ffc10cd43d96"]
      },
      "dependencies": [
        "aws_iam_instance_profile.ec2_profile",
        "aws_security_group.web_sg"
      ]
    }
  ]
}
```

### Why Dependencies Matter for Deletion

When I remove resources from my configuration, Terraform uses this same `dependencies` list in state to work out the **deletion order** — and it deletes in reverse of the order things were created.

**Say the original config had:**
```hcl
resource "aws_iam_role" "ec2_role" { ... }
resource "aws_iam_instance_profile" "ec2_profile" { ... }
resource "aws_instance" "web_server" { ... }
```

**And I remove the instance and its profile, keeping only the role:**
```hcl
# Removed: aws_iam_instance_profile!
# Removed: aws_instance!

resource "aws_iam_role" "ec2_role" { ... }
```

**Terraform still deletes in the correct order:**

```bash
$ terraform apply

Plan: 0 to add, 0 to change, 2 to destroy.

aws_instance.web_server: Destroying... [id=i-077f37d5b08506306]
aws_instance.web_server: Destruction complete after 30s

aws_iam_instance_profile.ec2_profile: Destroying...
aws_iam_instance_profile.ec2_profile: Destruction complete after 1s

Apply complete! Resources: 0 added, 0 changed, 2 destroyed.
```

**Why this order?** State recorded that the instance depends on the profile, so Terraform deletes the instance first, then the profile — the reverse of how they were created.

---

## Performance Gains with State Caching

For small infrastructure, Terraform querying AWS on every `plan` or `apply` isn't noticeable. But once an environment has hundreds or thousands of resources, constantly re-fetching everything from AWS would make every command slow. Terraform avoids that with **state caching**.

### How Caching Works

The state file already stores each resource's attributes, so Terraform doesn't need to ask AWS for them again on every run:

```json
{
  "version": 4,
  "terraform_version": "1.5.0",
  "serial": 4,
  "lineage": "e35dde72-a943-de50-3c8b-1df8986e5a31",
  "resources": [
    {
      "mode": "managed",
      "type": "aws_instance",
      "name": "web_server",
      "instances": [
        {
          "attributes": {
            "id": "i-077f37d5b08506306",
            "instance_type": "t2.micro",
            "ami": "ami-0c3a3c65a049b6922",
            "private_ip": "172.31.15.133",
            "public_ip": "3.231.50.210",
            "availability_zone": "us-east-1a"
          }
        }
      ]
    }
  ]
}
```

**Normal behavior (with refresh):**
```bash
$ terraform plan

aws_instance.web_server: Refreshing state... [id=i-077f37d5b08506306]

No changes. Your infrastructure matches the configuration.
```

Terraform reads the state file, asks AWS "does this instance still exist and match?", compares the attributes, and shows the plan. It's fast because it mostly trusts what's already in state and only checks for drift.

### Performance Option: Skip Refresh

For very large infrastructure, or when I just want a quick check, I can skip the AWS round-trip entirely with `--refresh=false`:

```bash
$ terraform plan --refresh=false

An execution plan has been generated and is shown below.

No changes. Your infrastructure matches the configuration.

Plan: 0 to add, 0 to change, 0 to destroy.
```

**What this does:**
- Uses the cached state file only — no AWS queries at all
- Very fast, since there's no refresh step
- Assumes the state file is still accurate
- Won't catch any manual changes made outside Terraform

**When it's worth using `--refresh=false`:**
- Large infrastructure with thousands of resources
- Quick CI/CD sanity checks
- I've already confirmed state is current

**When to avoid it:**
- Right after making manual changes in the AWS console
- The first apply after a long gap
- Anything production-critical

---

## Enhancing Team Collaboration with Remote State

For a solo project, keeping `terraform.tfstate` on my own machine works fine. But the moment more than one person runs Terraform against the same infrastructure, a single shared, up-to-date state file becomes critical — otherwise everyone's local copy drifts apart.

### The Problem: Local State in Teams

```bash
# Developer 1's machine
terraform.tfstate (serial: 5)

# Developer 2's machine
terraform.tfstate (serial: 3)  ← outdated!

# Actual AWS infrastructure
Matches serial: 5

Result: two different "truths" on two machines → conflicting changes → broken infrastructure
```

### The Solution: Remote State Storage

Store the state file in one shared, centralized location instead of on each developer's laptop:

```bash
# AWS S3 backend — every developer points at the same file
s3://my-terraform-state/terraform.tfstate (serial: 5)

# Developer 1's machine
(no local state file — reads from S3)

# Developer 2's machine
(no local state file — reads from S3)

Result: everyone works off the same state → consistent infrastructure
```

### Example: AWS S3 Remote State

**Create an S3 bucket to hold the state:**

```hcl
resource "aws_s3_bucket" "terraform_state" {
  bucket = "my-company-terraform-state"
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}
```

**Point Terraform at that bucket as its backend:**

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "my-company-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"  # for state locking
  }
}
```

**What this gets the team:**
```bash
Developer 1 runs:
  $ terraform apply
  → updates the shared S3 state

Developer 2 runs:
  $ terraform plan
  → reads the latest S3 state (serial: 6)
  → sees Developer 1's changes
  → plans against the current infrastructure, not a stale local copy
```

I'll cover backend configuration itself — S3 + DynamoDB locking in detail — in a later module; this section is just about *why* teams need it.

---

## Summary

The state file is the single source of truth for my AWS infrastructure, and everything in this note comes back to that one idea:

- **Maps config to reality** — links my HCL code to the actual AWS resources it created
- **Tracks dependencies** — knows the right order to create things in, and the reverse order to destroy them in
- **Enables performance** — caches resource attributes so Terraform isn't re-querying AWS on every command
- **Facilitates team work** — can be stored remotely (e.g. S3) so everyone works off the same state instead of their own local copy
- **Maintains history** — the `.tfstate.backup` file keeps a copy of the state from just before the last change

---

## Related Notes

- [Module 04.0: Introduction to Terraform State](../module-04.0-introduction-to-terraform-state/) — the hands-on lab this note's examples are pulled from

## Official Resources

- [Terraform State Documentation](https://www.terraform.io/language/state)
- [Terraform Backend Configuration](https://www.terraform.io/language/settings/backends/configuration)
- [S3 Backend Reference](https://www.terraform.io/language/settings/backends/s3)
