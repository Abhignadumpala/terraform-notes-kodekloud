# 📘 Module 10.1: What are Modules

> In this note, I explain what Terraform modules are and how I use them to make my Terraform configurations simpler and split into reusable parts.

---

## Overview

Terraform configuration files can grow long and complex. At first I started with simple resources like a local file or a random pet. But once I began deploying bigger AWS resources — IAM roles, policies, S3 buckets, DynamoDB tables, and EC2 instances — my configurations became repetitive and hard to manage.

For example, say I have a configuration with two EC2 instances, a key pair, a security group, and a DynamoDB table. The two EC2 instance blocks are almost the same, so I end up copying the same code twice.

Terraform has no strict limit on how many resources go in one file. I could put hundreds of resources in a single file, but then the file grows to thousands of lines. Another option is to split the configuration into many files in the same folder. Terraform reads every file with a `.tf` extension in the folder, no matter how I split them.

Here is how I could spread my resources across multiple files:

```hcl
# main.tf
resource "aws_instance" "webserver" {
  # configuration here
}
```

```hcl
# key_pair.tf
resource "aws_key_pair" "web" {
  # configuration here
}
```

```hcl
# dynamodb_table.tf
resource "aws_dynamodb_table" "state-locking" {
  # configuration here
}
```

```hcl
# security_group.tf
resource "aws_security_group" "ssh-access" {
  # configuration here
}
```

```hcl
# ec2_instance.tf
resource "aws_instance" "webserver-2" {
  # configuration here
}
```

```hcl
# s3_bucket.tf
resource "aws_s3_bucket" "terraform-state" {
  # configuration here
}
```

Splitting into files makes things tidier, but it does not fully fix two problems:

- The folder still gets more complex, and code is still repeated.
- A change in one part of the configuration can accidentally affect resources in another part.

Also, if I want to share part of my configuration with a teammate, I have to copy and paste the code, which can bring in mistakes.

This is what a typical Terraform project folder can look like:

```bash
$ ls
provider.tf
id_rsa
id_rsa.pub
main.tf
pub_ip.txt
terraform.tfstate.backup
terraform.tfstate
iam_roles.tf
iam_users.tf
security_groups.tf
variables.tf
outputs.tf
s3_buckets.tf
dynamo_db.tf
local.tf
```

> 💡 Modules help me manage complexity, cut repeated code, and reuse the same code across projects and environments.

---

## What Is a Terraform Module?

A Terraform module is any folder that contains a set of `.tf` files. So every Terraform configuration folder I have used so far is already a module.

For example, say I have a folder named `aws-instance` under `/root/terraform-projects`. It holds the Terraform files needed to create a simple EC2 instance in AWS. Since it has valid Terraform files, it is a module.

```bash
$ ls /root/terraform-projects/aws-instance
main.tf
variables.tf
```

`main.tf`:

```hcl
resource "aws_instance" "webserver" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = var.key
}
```

`variables.tf`:

```hcl
variable "ami" {
  type        = string
  default     = "ami-0edab43b6fa892279"
  description = "Ubuntu AMI ID in the ca-central-1 region"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key" {
  type    = string
  default = "webserver"
}
```

`main.tf` uses three variables, so `variables.tf` declares all three. Each one has a default, so the module works without me passing any values.

> ⚠️ An AMI ID only works in one region, and AMI IDs get replaced over time. I check the current Ubuntu AMI ID for my region before using this default.

A safer way is to not hard-code the AMI ID at all, and look it up with a `data` block instead. Terraform then finds the latest Ubuntu AMI in whatever region I'm working in, so I never use a wrong or old ID:

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical, the publisher of Ubuntu

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_instance" "webserver" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key

  lifecycle {
    ignore_changes = [ami]
  }
}
```

With this, the `ami` variable isn't needed. The `lifecycle` block stops one surprise: when Ubuntu publishes a newer AMI, the lookup returns a new ID, and without `ignore_changes` Terraform would destroy and recreate my instance to use it. I used the same lookup in [8.3](../../module-08-terraform-provisioners/module-08.3-aws-ec2-with-terraform/README.md). Official docs: [`aws_ami` data source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami).

When I run Terraform commands from inside the `aws-instance` folder, that folder is called the **root module**.

Official docs: [Modules overview](https://developer.hashicorp.com/terraform/language/modules).

---

## Reusing Modules for Different Environments

Now say I want to reuse the `aws-instance` module to create a new development web server, without copying the code. These are the steps:

1. Create a new folder named `development` under `terraform-projects`:

   ```bash
   $ mkdir /root/terraform-projects/development
   ```

2. Inside `development`, create a file (for example, `main.tf`) that points to the `aws-instance` module:

   ```hcl
   module "dev-webserver" {
     source = "../aws-instance"
   }
   ```

3. Run `terraform init` inside `development`, then `plan` and `apply` as usual:

   ```bash
   $ cd /root/terraform-projects/development
   $ terraform init
   $ terraform plan
   ```

In this setup, `development` is the **root module** (because I run Terraform commands from there), and `aws-instance` is a **child module**.

The `module` keyword is followed by a name I pick, here `dev-webserver`. Inside the block, the only required argument is `source`. It is the path to the child module folder that holds the EC2 instance code. Here I use the relative path `"../aws-instance"`, which points to the folder next to `development`. A local path must start with `./` or `../`.

> ⚠️ Terraform only finds a module after `terraform init`. Every time I add a `module` block or change its `source`, I run `terraform init` again. Official docs: [Module sources](https://developer.hashicorp.com/terraform/language/modules/sources).

This way I stop repeating code, updates are easier (I change the module once), and I can reuse the same code in different environments or projects.

> 💡 Modules also keep each piece of infrastructure in its own folder, which makes my configurations easier to manage and share.

Learn more:

- [Terraform Modules](https://developer.hashicorp.com/terraform/language/modules)
- [Module Blocks](https://developer.hashicorp.com/terraform/language/modules/syntax)
- [Terraform Configuration Language](https://developer.hashicorp.com/terraform/language)

---

## Summary

- ✅ A module is any folder with `.tf` files — every configuration folder is already a module
- ✅ The folder I run Terraform commands from is the root module
- ✅ A `module` block calls a child module, and `source` gives its path
- ✅ A local `source` path starts with `./` or `../`
- ⚠️ After adding a `module` block or changing its `source`, I run `terraform init` again
- ✅ Modules cut repeated code and let me reuse the same code across environments

---

## Key Takeaway

**A module is just a folder of `.tf` files. I write the code once and call it with a `module` block wherever I need it.**

- ✅ Root module = where I run Terraform. Child module = the folder `source` points to.
- ⚠️ `terraform init` must run before Terraform can use a new module

---

## Practice & Next Steps

Create the `aws-instance` and `development` folders from this note, run `terraform init` and `terraform plan` inside `development`, and check that the plan shows `module.dev-webserver.aws_instance.webserver`.

Next up: 10.2 — creating and using my own modules.
