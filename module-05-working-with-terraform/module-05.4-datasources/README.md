# 📘 Module 5.4: Datasources

> Reading information from resources that already exist outside your Terraform config, instead of hardcoding it

> 🧪 **Hands-on lab:** pending — code and screenshots to follow.

---

## Introduction

Terraform can provision infrastructure from scratch, but it can also read information about resources that already exist — created manually, by another tool (CloudFormation, Ansible, a script), or by a different Terraform configuration entirely. That's what **datasources** are for.

**Example:** You need an AMI (Amazon Machine Image) that already exists in AWS. Instead of hardcoding the AMI ID in your config, a datasource fetches it dynamically. If AWS publishes a newer version of that AMI, your Terraform picks it up automatically. ✅

---

## Understanding the Problem

### The Problem: Hardcoded Values

Without a datasource, the AMI ID is just a literal string in the resource block:

```hcl
resource "aws_instance" "app" {
  ami           = "ami-0fb0b230890ccd1e6"  # Hardcoded!
  instance_type = "t2.micro"
}
```

**Problems:**
- ❌ AWS updates the AMI → your code is stuck on the old one
- ❌ Move to a different region → that AMI ID doesn't exist there, code breaks
- ❌ Share the code with a teammate → they may need a different AMI for their account
- ❌ Not reusable

### The Solution: Use a Datasource

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "aws_instance" "app" {
  ami           = data.aws_ami.ubuntu.id  # Dynamic!
  instance_type = "t2.micro"
}
```

**Benefits:**
- ✅ Always resolves to the latest matching AMI
- ✅ Works across regions without changing the code
- ✅ A teammate can run the same config in their own account
- ✅ Flexible and reusable

---

## What is a Datasource?

A **datasource** is a block that reads information from something that already exists, without creating or managing it.

```
resource block:
  ├─ Creates infrastructure in AWS
  ├─ Stored in the state file
  ├─ Terraform can update/destroy it
  └─ keyword: resource

data block:
  ├─ Reads existing infrastructure
  ├─ NOT stored in the state file
  ├─ Read-only — no update or destroy
  └─ keyword: data
```

---

## Syntax

### Data Source Block

```hcl
data "PROVIDER_TYPE" "NAME" {
  argument = "value"
}
```

**Example:**
```hcl
data "aws_ami" "latest_ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-*"]
  }
}
```

### Referencing a Data Source

```hcl
data.PROVIDER_TYPE.NAME.ATTRIBUTE
```

**Example:**
```hcl
data.aws_ami.latest_ubuntu.id
# → "ami-0fb0b230890ccd1e6"
```

---

## Common AWS Datasources

### 1. Fetch the Latest AMI

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
}
```

**Why:** Never hardcode an AMI ID. When AWS publishes a newer patched image matching the filter, the next `terraform apply` picks it up.

---

### 2. Fetch a VPC by Tag

```hcl
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["main-vpc"]
  }
}

resource "aws_security_group" "web" {
  vpc_id = data.aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }
}
```

**Why:** Don't hardcode a VPC ID — look it up by tag instead, so the same config works across accounts and regions.

---

### 3. Fetch Available Availability Zones

```hcl
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_instance" "app" {
  availability_zone = data.aws_availability_zones.available.names[0]
  ami               = data.aws_ami.ubuntu.id
  instance_type     = "t2.micro"
}
```

**Why:** Automatically works in whatever region you deploy to, without hardcoding AZ names.

---

## When to Use Datasources

✅ **Use datasources for:**
- Reading existing infrastructure (AMI IDs, VPC info, AZs)
- Avoiding hardcoded values
- Making code portable across regions and accounts
- Referencing resources managed outside this Terraform config

❌ **Don't use datasources for:**
- Creating new infrastructure — use `resource`
- Managing resources this config owns — use `resource`

---

## Resource vs Datasource

| Type | Purpose | Managed by Terraform |
|---|---|---|
| **Resource** | Create, update, and destroy infrastructure | Yes — stored in `terraform.tfstate` |
| **Datasource** | Read and reference existing infrastructure | No — read-only, not stored in state |

---

## Summary

- A **datasource** reads information about something that already exists — it never creates, updates, or destroys anything.
- The main win is avoiding **hardcoded values**: AMI IDs, VPC IDs, AZ names — anything that changes between regions, accounts, or over time as AWS updates it.
- Datasources aren't tracked in the state file the way resources are — they're just a lookup, re-evaluated on every `plan`/`apply`.

**No more hardcoding!** 🚀
