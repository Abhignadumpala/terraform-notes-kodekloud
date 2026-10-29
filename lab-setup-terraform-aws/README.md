# Lab Setup — Connect Terraform to AWS and Create Your First Resources

[← Back to all notes](../README.md)

> **In short:** Terraform creates AWS resources by calling the AWS API **as an IAM user**. So first you create an IAM user with permissions, save its keys on your laptop with `aws configure`, install Terraform, and then write `.tf` files and run `init → plan → apply`.

## Table of Contents

1. [How it works](#how-it-works)
2. [Authentication vs authorization](#authentication-vs-authorization)
3. [Step 1: Create an IAM user](#step-1-create-an-iam-user)
4. [Step 2: Create an access key](#step-2-create-an-access-key)
5. [Step 3: Install the AWS CLI](#step-3-install-the-aws-cli)
6. [Step 4: Run aws configure](#step-4-run-aws-configure)
7. [Step 5: Install Terraform](#step-5-install-terraform)
8. [Step 6: Write the Terraform files](#step-6-write-the-terraform-files)
9. [Step 7: Run init, plan, apply](#step-7-run-init-plan-apply)
10. [Step 8: Check in AWS](#step-8-check-in-aws)
11. [Step 9: Destroy (clean up)](#step-9-destroy-clean-up)
12. [If something fails](#if-something-fails)
13. [Interview One-Liners](#interview-one-liners)

---

## How it works

```
 ① aws configure                       ② terraform apply
 (access key + secret)                 (reads your .tf files)
        │                                      │
        ▼                                      ▼
 ~/.aws/credentials ──── read by ────► AWS provider plugin
                                               │
                                               ▼  API call signed with the IAM user's keys
                                         AWS checks the user's IAM policies
                                               │
                                     allowed ✅ → EC2 + SG created
                                     denied  ❌ → AccessDenied error
```

**Terraform has no permissions of its own.** It uses whatever credentials it finds, and the **IAM policies on that user** decide what it can create.

## Authentication vs authorization

| | Authentication | Authorization |
|---|---|---|
| Question | **Who are you?** | **What are you allowed to do?** |
| In this lab | the IAM user's **access key + secret** | the **IAM policies** attached to the user |
| Where | `~/.aws/credentials` on your laptop | IAM → Users → Permissions |

The user needs permission for the **whole lifecycle** of each resource:

| Terraform command | Needs permission to |
|---|---|
| `plan` | **read** (e.g. `ec2:DescribeInstances`) |
| `apply` | **create / update** (e.g. `ec2:RunInstances`, `ec2:CreateSecurityGroup`) |
| `destroy` | **delete** (e.g. `ec2:TerminateInstances`) |

## Step 1: Create an IAM user

**Definition:** an *IAM user* = an identity in your AWS account for one person or tool, with its own credentials.

1. AWS console → **IAM** → **Users** → **Create user**.
2. Name: e.g. `terraform-user`.
3. **Permissions** → **Attach policies directly** → select **`AdministratorAccess`** (fine for learning).
4. **Create user**.

> In real jobs, give **least privilege**: only the permissions for the resources Terraform manages (e.g. only EC2 + S3), not Admin.

## Step 2: Create an access key

**Definition:** an *access key* = a key ID + secret that lets a program (CLI, Terraform) log in as the IAM user.

1. IAM → Users → `terraform-user` → **Security credentials** tab.
2. **Create access key** → use case **Command Line Interface (CLI)** → Next → **Create**.
3. Copy the **Access key ID** and **Secret access key** (the secret is shown **only once**; download the `.csv`).

> ⚠️ The access key is like a password. Never put it in a `.tf` file or push it to GitHub.

## Step 3: Install the AWS CLI

Ubuntu / Linux:
```bash
sudo apt-get install -y unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version            # aws-cli/2.x.x ...
```

## Step 4: Run aws configure

```bash
aws configure
```
```
AWS Access Key ID [None]: <your-access-key-id>
AWS Secret Access Key [None]: <your-secret-access-key>
Default region name [None]: us-east-1
Default output format [None]: json
```

It saves 2 files:

| File | Holds |
|---|---|
| `~/.aws/credentials` | access key + secret |
| `~/.aws/config` | region + output format |

**Check it works:**
```bash
aws sts get-caller-identity
```
```json
{
    "UserId": "AIDA...",
    "Account": "<your-account-id>",
    "Arn": "arn:aws:iam::<your-account-id>:user/terraform-user"
}
```
If you see your user name → authentication works ✅.

## Step 5: Install Terraform

Ubuntu:
```bash
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform -y
terraform version        # Terraform v1.x.x
```

## Step 6: Write the Terraform files

Lab: **one EC2 server linked to one security group.**

```bash
mkdir ec2-sg-lab && cd ec2-sg-lab
```

```
ec2-sg-lab/
├── provider.tf          # terraform block + provider block
├── security_group.tf    # firewall: allow SSH (22) + HTTP (80)
├── ec2_instance.tf      # the server, linked to the SG
└── outputs.tf           # print IDs and public IP after apply
```

**`provider.tf`**: which plugin to download, and which region to use.
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"     # no keys here: they come from ~/.aws/credentials
}
```

| Block | Job |
|---|---|
| `terraform {}` | Terraform's own settings: which provider + version to download |
| `provider "aws" {}` | how to talk to AWS: region (credentials are read from `~/.aws/`) |

**`security_group.tf`**:
```hcl
resource "aws_security_group" "allow_ssh" {
  name        = "allow-ssh"
  description = "Allow SSH and HTTP"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["<your-ip>/32"]     # curl checkip.amazonaws.com
  }

  ingress {
    from_port   = 80
    to_port     = 80
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
```

**`ec2_instance.tf`**:
```hcl
resource "aws_instance" "web_server" {
  ami           = "<ami-id>"            # EC2 console → Launch instance → copy an AMI ID for your region
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.allow_ssh.id]   # links EC2 → SG

  tags = {
    Name = "web-server"
  }
}
```

`aws_security_group.allow_ssh.id` = "the ID of the SG above". Because EC2 uses it, Terraform knows to create the **SG first, then EC2** (implicit dependency).

**`outputs.tf`**:
```hcl
output "instance_id" {
  value = aws_instance.web_server.id
}

output "instance_public_ip" {
  value = aws_instance.web_server.public_ip
}

output "security_group_id" {
  value = aws_security_group.allow_ssh.id
}
```

## Step 7: Run init, plan, apply

Run inside the `ec2-sg-lab` folder:

| # | Command | What it does |
|---|---|---|
| 1 | `terraform init` | downloads the AWS provider into `.terraform/` |
| 2 | `terraform fmt` | formats the code neatly |
| 3 | `terraform validate` | checks the syntax |
| 4 | `terraform plan` | preview: `Plan: 2 to add, 0 to change, 0 to destroy` |
| 5 | `terraform apply` | type `yes` → creates SG, then EC2 |
| 6 | `terraform output` | prints instance ID, public IP, SG ID |

After `apply`, Terraform writes **`terraform.tfstate`**: its record of what it created. Don't edit or delete it by hand.

## Step 8: Check in AWS

- Console: **EC2 → Instances** → `web-server` running, **Security** tab shows `allow-ssh`.
- Or from the terminal:
  ```bash
  terraform state list
  aws ec2 describe-instances --filters "Name=tag:Name,Values=web-server" \
    --query 'Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress]' --output table
  ```

## Step 9: Destroy (clean up)

```bash
terraform destroy        # type yes → deletes EC2, then SG
terraform state list     # empty = nothing left
```

Always destroy after a lab so you don't pay for running servers.

## If something fails

| Error | Fix |
|---|---|
| `No valid credential sources found` | run `aws configure` (Step 4), check with `aws sts get-caller-identity` |
| `UnauthorizedOperation` / `AccessDenied` | the IAM user is missing a permission → add the policy in IAM |
| `InvalidAMIID.NotFound` | AMI ID is from another region → copy one from **your** region |
| `Missing required argument: region` | add `region` in the `provider "aws"` block |

## Interview One-Liners

- **Prerequisites:** IAM user with permissions → access key → `aws configure` → Terraform installed.
- **Authentication** = access key proves who you are; **authorization** = IAM policies decide what you can do.
- **Terraform has no AWS permissions of its own**; it uses the credentials it's given.
- **No keys in `.tf` files**: the AWS provider reads `~/.aws/credentials`, the same as the CLI.
- **Workflow:** `init → plan → apply → destroy`.
- **Least privilege:** in production the Terraform user/role gets only the permissions it needs, not Admin.
