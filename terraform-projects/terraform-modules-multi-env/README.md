# 🧪 Hands-On Project: Reusable Terraform Modules for Dev, Staging & Production

> I build one real project from scratch: an S3 remote backend, a custom VPC, a security group, EC2 web servers (AMI found with a data block), and an IAM role for the servers. Everything is written as modules once, then reused by the dev, staging, and production environments — each environment calls only the modules it needs.

---

## What I Build

```
web-app-infra/
├── bootstrap/                  # Step 1: creates the S3 bucket for remote state (run once)
│   └── main.tf
├── modules/                    # Reusable code — written ONCE
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── security-group/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ec2/
│   │   ├── main.tf             # includes the data block for the AMI
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── iam/
│       ├── main.tf             # role + instance profile for the servers
│       ├── variables.tf
│       └── outputs.tf
├── environments/               # Each environment CALLS the modules it needs
│   ├── dev/                    # vpc + security-group + ec2
│   │   ├── main.tf             # terraform block → backend → provider → modules
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── outputs.tf
│   ├── staging/                # vpc + security-group + ec2 + iam
│   │   └── (same 4 files, different tfvars + backend key)
│   └── production/             # vpc + security-group + ec2 + iam
│       └── (same 4 files, different tfvars + backend key)
├── .gitignore
└── README.md
```

**How the pieces connect:**

```
module "vpc"  ──vpc_id──────────────►  module "security_group"
     │                                         │
     └──public_subnet_ids──►  module "ec2"  ◄──security_group_id
                                   ▲
       module "iam" ──instance_profile_name──┘   (staging + production only)
```

|  | dev | staging | production |
|--|-----|---------|------------|
| VPC CIDR | `10.0.0.0/16` | `10.1.0.0/16` | `10.2.0.0/16` |
| Instance type | `t3.micro` | `t3.small` | `t3.small` |
| Number of servers | 1 | 2 | 3 |
| IAM module (SSM access) | no | yes | yes |
| State file in S3 | `dev/terraform.tfstate` | `staging/terraform.tfstate` | `production/terraform.tfstate` |

**Region:** `eu-west-1` (Ireland) for all three. **Time:** about 2 hours. **Cost:** small if I destroy at the end. There is no NAT Gateway on purpose — it's the most expensive part of a typical VPC.

---

## Phase 0 — Prerequisites

```bash
terraform -version            # 1.11 or newer (needed for S3 native locking)
aws sts get-caller-identity   # confirms my AWS credentials work
```

Create the folders (inside this repo, so the code is saved next to this README):

```bash
cd ~/terraform-notes-kodekloud/terraform-projects/web-app-infra
mkdir -p bootstrap modules/{vpc,security-group,ec2,iam} environments/{dev,staging,production}
```

`.gitignore` in the project folder:

```
.terraform/
*.tfstate
*.tfstate.*
crash.log
```

> 💡 I commit `.terraform.lock.hcl` — it pins provider versions so everyone gets the same ones.

---

## Phase 1 — Bootstrap: Create the S3 Backend Bucket

**Why a separate step?** The backend bucket must exist before any environment can store its state in it. Terraform can't store its state in a bucket it hasn't created yet. So this small folder uses local state and runs once.

### `bootstrap/main.tf`

```hcl
terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

resource "aws_s3_bucket" "tfstate" {
  bucket = "abhigna-tfstate-2026" # must be globally unique — change it

  # The state bucket holds every environment's state — Terraform refuses to destroy it
  lifecycle {
    prevent_destroy = true
  }
}

# Keep old versions of the state file, so a bad apply can be recovered
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# State files can contain secrets — never make them public
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "state_bucket_name" {
  value = aws_s3_bucket.tfstate.id
}
```

```bash
cd bootstrap
terraform init
terraform apply
```

✅ **Checkpoint:** `aws s3 ls | grep tfstate` shows my bucket.

> ⚠️ With `prevent_destroy = true`, any plan that would delete this bucket fails with `Instance cannot be destroyed`. That's the point — losing this bucket means losing the state of every environment. Phase 11 shows how to remove it on purpose.

---

## Phase 2 — Dev Environment: Terraform Block, Backend, Provider

Now I start the dev environment in the order a real project is written.

### `environments/dev/main.tf` (first part)

```hcl
# ─── 1. Terraform block ─────────────────────────────────────
terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # ─── 2. S3 backend: where the state file lives ──────────
  backend "s3" {
    bucket       = "abhigna-tfstate-2026"   # the bucket from Phase 1
    key          = "dev/terraform.tfstate"  # different key per environment
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true                     # locks state during apply (no DynamoDB needed)
  }
}

# ─── 3. Provider ────────────────────────────────────────────
provider "aws" {
  region = var.aws_region

  # Added to every resource this provider creates
  default_tags {
    tags = {
      Project     = "web-app"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
```

> ⚠️ The backend block cannot use variables. That's why the bucket name and key are typed in directly. Each environment has its own key, so dev, staging, and production never share a state file.

### `environments/dev/variables.tf`

```hcl
variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "One CIDR per public subnet (one subnet per Availability Zone)"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "instance_count" {
  description = "How many web servers to create"
  type        = number
}
```

### `environments/dev/terraform.tfvars`

```hcl
environment         = "dev"
aws_region          = "eu-west-1"
vpc_cidr            = "10.0.0.0/16"
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
instance_type       = "t3.micro"
instance_count      = 1
```

```bash
cd ../environments/dev
terraform init
```

✅ **Checkpoint:** the output says `Successfully configured the backend "s3"!`. Nothing is created yet — I just connected dev to remote state.

---

## Phase 3 — VPC Module

### `modules/vpc/main.tf`

```hcl
# Find the Availability Zones in the current region
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.environment}-vpc"
  }
}

# Lets the public subnets reach the internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment}-igw"
  }
}

# One public subnet per CIDR, each in a different AZ
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment}-public-${count.index + 1}"
  }
}

# Route all internet traffic (0.0.0.0/0) through the internet gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.environment}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
```

### `modules/vpc/variables.tf`

```hcl
variable "environment" {
  description = "Environment name, used in Name tags"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets"
  type        = list(string)
}
```

### `modules/vpc/outputs.tf`

```hcl
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}
```

### Call it from dev — add to `environments/dev/main.tf`

```hcl
# ─── 4. Modules ─────────────────────────────────────────────
module "vpc" {
  source = "../../modules/vpc"

  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
}
```

```bash
terraform init      # needed every time I add a new module
terraform plan
```

✅ **Checkpoint:** `Plan: 7 to add` — 1 VPC, 1 internet gateway, 2 subnets, 1 route table, 2 associations. Don't apply yet; keep building.

---

## Phase 4 — Security Group Module

### `modules/security-group/main.tf`

```hcl
resource "aws_security_group" "web" {
  name        = "${var.environment}-web-sg"
  description = "Allow web traffic to the ${var.environment} servers"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.environment}-web-sg"
  }
}

# One inbound rule per port in var.ingress_ports
resource "aws_vpc_security_group_ingress_rule" "web" {
  for_each = { for port in var.ingress_ports : tostring(port) => port }

  security_group_id = aws_security_group.web.id
  cidr_ipv4         = var.allowed_cidr
  from_port         = each.value
  to_port           = each.value
  ip_protocol       = "tcp"
}

# Allow all outbound traffic (needed to download packages)
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
```

> 💡 The AWS provider docs recommend separate `ingress_rule` / `egress_rule` resources instead of inline `ingress {}` blocks. Also: when Terraform creates a security group, it removes AWS's default allow-all outbound rule — that's why the egress rule is written out.

### `modules/security-group/variables.tf`

```hcl
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC to create the security group in"
  type        = string
}

variable "ingress_ports" {
  description = "Ports to open for inbound traffic"
  type        = list(number)
  default     = [80]
}

variable "allowed_cidr" {
  description = "Who can reach the open ports"
  type        = string
  default     = "0.0.0.0/0"
}
```

### `modules/security-group/outputs.tf`

```hcl
output "security_group_id" {
  description = "ID of the web security group"
  value       = aws_security_group.web.id
}
```

### Call it from dev

```hcl
module "security_group" {
  source = "../../modules/security-group"

  environment = var.environment
  vpc_id      = module.vpc.vpc_id   # output of one module → input of another
}
```

> 💡 `module.vpc.vpc_id` creates an automatic dependency: Terraform knows it must build the VPC first. No `depends_on` needed.

```bash
terraform init && terraform plan
```

✅ **Checkpoint:** `Plan: 10 to add`.

---

## Phase 5 — EC2 Module (with the AMI Data Block)

### `modules/ec2/main.tf`

```hcl
# Look up the latest Amazon Linux 2023 AMI in whatever region the provider uses
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "web" {
  count = var.instance_count

  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)] # spread across AZs
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = var.iam_instance_profile # null = no IAM role attached

  # Require IMDSv2 (security best practice)
  metadata_options {
    http_tokens = "required"
  }

  # Install nginx and show which environment and server this is
  user_data = <<-EOF
    #!/bin/bash
    dnf install -y nginx
    echo "<h1>Hello from ${var.environment} - server ${count.index + 1}</h1>" > /usr/share/nginx/html/index.html
    systemctl enable --now nginx
  EOF

  user_data_replace_on_change = true

  tags = {
    Name = "${var.environment}-web-${count.index + 1}"
  }
}
```

> 💡 Why the data block? AMI IDs are different in every region and change when Amazon releases updates. The data block finds the right one at plan time, so the module works anywhere without hard-coded IDs. The name filter is `al2023-ami-2023.*` (not just `al2023-ami-*`) so it skips the `al2023-ami-minimal-*` images, which have fewer packages installed.

> ⚠️ When Amazon releases a newer AMI, the next `plan` wants to replace the servers. That's fine for this lab. For long-lived servers, `lifecycle { ignore_changes = [ami] }` stops it — see [10.1](../../module-10-terraform-modules/module-10.1-what-are-modules/README.md).

### `modules/ec2/variables.tf`

```hcl
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small"], var.instance_type)
    error_message = "For this project, instance_type must be t3.micro or t3.small."
  }
}

variable "instance_count" {
  description = "Number of web servers"
  type        = number
  default     = 1
}

variable "subnet_ids" {
  description = "Subnets to place the servers in"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group to attach to the servers"
  type        = string
}

variable "iam_instance_profile" {
  description = "Instance profile to attach (from the iam module). Leave null for no IAM role."
  type        = string
  default     = null
}
```

> 💡 `iam_instance_profile` has `default = null`, so it's optional. Dev doesn't pass it and gets servers with no IAM role. Staging and production pass the IAM module's output. This is how an environment uses a module only when it needs it.

### `modules/ec2/outputs.tf`

```hcl
output "instance_ids" {
  description = "IDs of the web servers"
  value       = aws_instance.web[*].id
}

output "public_ips" {
  description = "Public IPs of the web servers"
  value       = aws_instance.web[*].public_ip
}

output "ami_id" {
  description = "AMI the data block found"
  value       = data.aws_ami.al2023.id
}
```

### Call it from dev

```hcl
module "ec2" {
  source = "../../modules/ec2"

  environment       = var.environment
  instance_type     = var.instance_type
  instance_count    = var.instance_count
  subnet_ids        = module.vpc.public_subnet_ids
  security_group_id = module.security_group.security_group_id
}
```

### `environments/dev/outputs.tf`

```hcl
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "ami_id" {
  value = module.ec2.ami_id
}

output "website_urls" {
  value = [for ip in module.ec2.public_ips : "http://${ip}"]
}
```

---

## Phase 6 — Deploy Dev & Test

```bash
terraform init
terraform fmt -recursive ../..
terraform validate
terraform plan
terraform apply
```

✅ **Checkpoints:**

- `Plan: 11 to add` (7 VPC + 3 security group + 1 EC2).
- `terraform state list` — every address starts with `module.`, for example `module.ec2.aws_instance.web[0]`.
- Wait 1–2 minutes for nginx to install, then:

  ```bash
  curl $(terraform output -json website_urls | jq -r '.[0]')
  ```

  I should see `Hello from dev - server 1`.
- My state is in S3, not on my laptop:

  ```bash
  aws s3 ls s3://abhigna-tfstate-2026/dev/
  ```

  There's no `terraform.tfstate` file in the dev folder.

---

## Phase 7 — IAM Module

The servers in staging and production get an IAM role, so AWS Systems Manager (SSM) can manage them — for example, opening a shell with Session Manager instead of SSH. Dev doesn't need it, so dev never calls this module.

An EC2 instance can't use an IAM role directly. The role goes inside an **instance profile**, and the instance profile is attached to the instance.

### `modules/iam/main.tf`

```hcl
# Who can use this role: the EC2 service
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "web" {
  name               = "${var.environment}-web-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# What the role can do: the AWS-managed policy SSM needs on an instance
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# The wrapper that attaches the role to EC2 instances
resource "aws_iam_instance_profile" "web" {
  name = "${var.environment}-web-profile"
  role = aws_iam_role.web.name
}
```

> 💡 IAM names must be unique in the whole AWS account (IAM isn't per region), so the environment name goes in front: `staging-web-role`, `production-web-role`.

### `modules/iam/variables.tf`

```hcl
variable "environment" {
  description = "Environment name, used in IAM names"
  type        = string
}
```

### `modules/iam/outputs.tf`

```hcl
output "instance_profile_name" {
  description = "Instance profile to pass to the ec2 module"
  value       = aws_iam_instance_profile.web.name
}

output "role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.web.name
}
```

No `terraform apply` in this phase — the module is only used once staging calls it.

---

## Phase 8 — Reuse the Modules for Staging

This is the whole point: no module code is written again.

```bash
cd ..
cp dev/main.tf dev/variables.tf dev/outputs.tf staging/
```

Make three changes:

1. In `staging/main.tf`, change the backend key:

   ```hcl
   key          = "staging/terraform.tfstate"
   ```

2. In `staging/main.tf`, add the IAM module and pass its output to the EC2 module:

   ```hcl
   module "iam" {
     source = "../../modules/iam"

     environment = var.environment
   }

   module "ec2" {
     source = "../../modules/ec2"

     environment          = var.environment
     instance_type        = var.instance_type
     instance_count       = var.instance_count
     subnet_ids           = module.vpc.public_subnet_ids
     security_group_id    = module.security_group.security_group_id
     iam_instance_profile = module.iam.instance_profile_name   # the new line
   }
   ```

3. Create `staging/terraform.tfvars`:

   ```hcl
   environment         = "staging"
   aws_region          = "eu-west-1"
   vpc_cidr            = "10.1.0.0/16"
   public_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
   instance_type       = "t3.small"
   instance_count      = 2
   ```

```bash
cd staging
terraform init
terraform apply
```

✅ **Checkpoints:**

- `Plan: 15 to add` — 7 VPC + 3 security group + 2 EC2 + 3 IAM (role, policy attachment, instance profile).
- Both URLs work and say `staging - server 1` and `staging - server 2`, in different AZs.
- The IAM role works: after 2–3 minutes, SSM sees both servers:

  ```bash
  aws ssm describe-instance-information --region eu-west-1 \
    --query 'InstanceInformationList[].InstanceId'
  ```

  Only the staging servers show up — the dev server has no IAM role, so SSM can't see it.
- `aws s3 ls s3://abhigna-tfstate-2026/ --recursive` shows two separate state files.

---

## Phase 9 — Production

Same as staging: copy the files, change the backend key, and write a new `terraform.tfvars`.

```bash
cd ..
cp staging/main.tf staging/variables.tf staging/outputs.tf production/
```

1. In `production/main.tf`, change the backend key:

   ```hcl
   key          = "production/terraform.tfstate"
   ```

2. Create `production/terraform.tfvars`:

   ```hcl
   environment         = "production"
   aws_region          = "eu-west-1"
   vpc_cidr            = "10.2.0.0/16"
   public_subnet_cidrs = ["10.2.1.0/24", "10.2.2.0/24"]
   instance_type       = "t3.small"
   instance_count      = 3
   ```

```bash
cd production
terraform init
terraform apply
```

✅ **Checkpoints:**

- `Plan: 16 to add` — like staging, plus one more server.
- Three URLs say `production - server 1/2/3`. With 2 subnets, servers 1 and 3 share an AZ (`count.index % 2`).
- `aws s3 ls s3://abhigna-tfstate-2026/ --recursive` shows three separate state files.
- In the EC2 console, dev, staging, and production servers sit in three different VPCs — fully isolated.

---

## Phase 10 — Change a Module Once, Update Every Environment

Open port 443 for every environment by changing one default in `modules/security-group/variables.tf`:

```hcl
  default     = [80, 443]
```

Run `terraform plan` in `dev/`, `staging/`, and `production/`.

✅ **Checkpoint:** all three plans show `1 to add` — a new ingress rule for port 443. One edit, every environment gets it on its next apply.

> 💡 This is also the risk: with local paths (`../../modules`), every environment picks up changes immediately — including production. Stretch goal A below fixes that with version tags.

---

## Phase 11 — Clean Up (Order Matters)

Destroy the environments first, the backend bucket last (the environments need it to read their state).

```bash
cd ../production && terraform destroy
cd ../staging && terraform destroy
cd ../dev && terraform destroy
```

The state bucket is protected by `prevent_destroy`, so `terraform destroy` in `bootstrap/` fails on purpose. In a real project I keep this bucket — it costs almost nothing. To remove it anyway:

1. In `bootstrap/main.tf`, delete the `lifecycle { prevent_destroy = true }` block and add `force_destroy = true` to the bucket (the bucket is versioned, so it still holds old state versions that S3 won't delete by itself).
2. Apply that change first, then destroy:

```bash
cd ../../bootstrap
terraform apply     # only updates force_destroy, nothing is deleted
terraform destroy
```

---

## Stretch Goals

**A. Versioned modules on GitHub.** Move `modules/` into its own repo, tag it `v1.0.0`, and change each `source` to:

```hcl
source = "git::https://github.com/Abhignadumpala/terraform-modules.git//vpc?ref=v1.0.0"
```

Now production can stay on `v1.0.0` while dev tests `v1.1.0`.

**B. SSH access.** Add a key pair (`aws_key_pair`), pass `key_name` to the EC2 module, and add port 22 with `allowed_cidr` set to my own IP only (`x.x.x.x/32`) — never `0.0.0.0/0`.

---

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `Module not installed` | Added a new module call | `terraform init` |
| `Backend configuration changed` | Edited the backend block | `terraform init -reconfigure` |
| S3 bucket does not exist | Bootstrap not applied, or name typo | Run Phase 1; match names exactly |
| `Variables may not be used here` | Used `var.` inside backend | Type the values directly |
| `Instance cannot be destroyed` | `prevent_destroy` on the state bucket | Expected — see Phase 11 to remove it on purpose |
| `Error acquiring the state lock` | Another apply running, or one crashed | Wait; if it crashed, `terraform force-unlock <ID>` |
| `curl` times out | nginx still installing, or port 80 missing | Wait 2 min; check the security group rules |
| `Unsupported argument "use_lockfile"` | Terraform older than 1.11 | Upgrade Terraform |

---

## Self-Check Questions

1. Why does the backend bucket live in a separate `bootstrap/` folder?
2. Why can't the backend block use `var.environment` for the key?
3. How does Terraform know to build the VPC before the security group?
4. Why is the AMI a data block instead of a variable?
5. What is different between the dev and staging folders?
6. Why does the EC2 module still work in dev, where the IAM module isn't called?

---

## Interview Version

> "I built the infrastructure as reusable modules — VPC, security group, EC2, and IAM — and each environment (dev, staging, production) is a small root module that calls only the modules it needs, with its own tfvars. State is stored remotely in S3 with native locking and a separate key per environment, so the environments are fully isolated. Modules pass values through outputs, like the VPC ID into the security group, which gives Terraform the dependency order automatically. The EC2 module finds the AMI with a data source, so it works in any region without hard-coded IDs, and takes an optional instance profile, so staging and production servers get an SSM role while dev stays minimal."

---

## Official Docs

- [Terraform block & `required_providers`](https://developer.hashicorp.com/terraform/language/block/terraform)
- [S3 backend (incl. `use_lockfile`)](https://developer.hashicorp.com/terraform/language/backend/s3)
- [Modules](https://developer.hashicorp.com/terraform/language/modules)
- [Data sources](https://developer.hashicorp.com/terraform/language/data-sources)
- [`count`](https://developer.hashicorp.com/terraform/language/meta-arguments/count) and [`for_each`](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each)
- AWS provider: [`aws_vpc`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc), [`aws_security_group`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group), [`aws_instance`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance), [`aws_iam_role`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role), [`aws_iam_instance_profile`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile), [`aws_ami` data source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami)
