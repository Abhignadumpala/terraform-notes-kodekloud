# 🧪 Hands-On Project: nginx Web App with Reusable Terraform Modules (Dev, Staging & Production)

> I build one real project from scratch: an nginx web server on EC2, with its own VPC, security group, and IAM role, and state stored in an S3 backend. Every piece is a small module. One central module, `nginx-web-app`, joins the four pieces together, and each environment (dev, staging, production) makes just **one** call to it with its own values.

---

## What I Build

```
terraform-modules-multi-env/
├── bootstrap/                  # Step 1: creates the S3 bucket for remote state (run once)
│   └── main.tf
├── modules/                    # All the real code — written ONCE
│   ├── vpc/                    # VPC, public subnet, internet gateway, route table
│   ├── security-group/         # firewall: HTTP 80 from anywhere, SSH 22 from my IP
│   ├── iam/                    # EC2 role + SSM policy + instance profile
│   ├── ec2/                    # nginx server (AMI found with a data block)
│   └── nginx-web-app/          # central module — calls the four above and joins them
├── environments/               # Each environment makes ONE call to nginx-web-app
│   ├── dev/
│   ├── staging/
│   └── production/
├── .gitignore
└── README.md
```

Every module folder has the same three files: `main.tf` (resources), `variables.tf` (inputs), `outputs.tf` (values it gives back).
Every environment folder has four: `main.tf`, `variables.tf`, `terraform.tfvars`, `outputs.tf`.

### How the pieces connect

```
environments/dev/terraform.tfvars
  → environments/dev/main.tf        module "nginx_web_app"
    → modules/nginx-web-app/main.tf
         vpc ──────────vpc_id──────────────► security_group
         vpc ──────────public_subnet_id────► ec2
         security_group ──security_group_id► ec2
         iam ──────────instance_profile_name► ec2
```

- The **environments** only know about `nginx-web-app`. They don't know there are four modules inside.
- **`nginx-web-app`** is the only place that knows how the pieces fit: it takes one module's output and passes it into the next module's input.
- The **four small modules** don't know about each other at all. They just take inputs and give outputs.

### What changes per environment

|  | dev | staging | production |
|--|-----|---------|------------|
| VPC CIDR | `10.0.0.0/16` | `10.1.0.0/16` | `10.2.0.0/16` |
| Public subnet CIDR | `10.0.1.0/24` | `10.1.1.0/24` | `10.2.1.0/24` |
| Instance type | `t3.micro` | `t3.micro` | `t3.small` |
| State file in S3 | `dev/terraform.tfstate` | `staging/terraform.tfstate` | `production/terraform.tfstate` |

Only `terraform.tfvars` and the backend `key` are different — the module code is the same for all three.

**Region:** `eu-west-1` (Ireland). **Cost:** small if I destroy at the end. No NAT Gateway on purpose (it's the most expensive part of a typical VPC) — the server sits in a public subnet.

---

## Progress

- [x] `bootstrap/` — S3 state bucket (applied)
- [x] `modules/vpc`
- [x] `modules/security-group`
- [x] `modules/iam`
- [x] `modules/ec2`
- [x] `modules/nginx-web-app`
- [ ] `environments/dev` — write, apply, test in browser
- [ ] `environments/staging`
- [ ] `environments/production`

---

## Step 0 — Prerequisites

```bash
terraform -version            # 1.11 or newer (needed for S3 native locking)
aws sts get-caller-identity   # confirms my AWS credentials work
curl ifconfig.me              # my public IP — goes into ssh_cidr as x.x.x.x/32
```

`.gitignore` keeps state and downloaded providers out of git:

```
.terraform/
*.tfstate
*.tfstate.*
crash.log
```

> 💡 I commit `.terraform.lock.hcl` only in the folders I actually run (`bootstrap/` and the environments). The module folders don't need one — if I run `terraform init` inside a module just to validate it, I delete `.terraform/` and `.terraform.lock.hcl` afterwards.

---

## Step 1 — Bootstrap: the S3 Backend Bucket

**Why a separate folder?** The bucket must exist *before* any environment can store its state in it — Terraform can't keep its state in a bucket it hasn't created yet. So `bootstrap/` uses local state and runs once.

What [`bootstrap/main.tf`](bootstrap/main.tf) creates:

| Resource | Why |
|----------|-----|
| `aws_s3_bucket` `abhigna-tfstate-2026` | holds the state of every environment |
| `lifecycle { prevent_destroy = true }` | Terraform refuses to delete it by accident |
| `aws_s3_bucket_versioning` | keeps old state versions, so a bad apply can be recovered |
| `aws_s3_bucket_public_access_block` | state can contain secrets — never public |

```bash
cd bootstrap
terraform init
terraform apply
```

✅ **Checkpoint:** `aws s3 ls | grep abhigna-tfstate-2026` shows my bucket.

> ⚠️ `bootstrap/terraform.tfstate` stays on my laptop and git ignores it. It's the only record of the bucket, so I keep it safe.

---

## Step 2 — The Four Small Modules

### `modules/vpc` — the network

| Resource | Name in code | What it does |
|----------|--------------|--------------|
| `data.aws_availability_zones` | `available` | finds the AZs in my region; the subnet uses the first one |
| `aws_vpc` | `nginx_vpc` | my own private network |
| `aws_subnet` | `public_subnet` | where EC2 runs; `map_public_ip_on_launch = true` gives it a public IP |
| `aws_internet_gateway` | `nginx_igw` | the door between the VPC and the internet |
| `aws_route_table` | `public_rt` | sends `0.0.0.0/0` through the gateway |
| `aws_route_table_association` | `public_rt_assoc` | attaches the route table to the subnet — **this** is what makes it "public" |

**Inputs:** `environment`, `vpc_cidr`, `public_subnet_cidr` → **Outputs:** `vpc_id`, `public_subnet_id`

### `modules/security-group` — the firewall

| Resource | Name in code | What it does |
|----------|--------------|--------------|
| `aws_security_group` | `nginx_sg` | the firewall itself, inside my VPC |
| `aws_vpc_security_group_ingress_rule` | `http` | port 80 from anywhere, so anyone can open the page |
| `aws_vpc_security_group_ingress_rule` | `ssh` | port 22 only from `ssh_cidr` (my IP) |
| `aws_vpc_security_group_egress_rule` | `all_outbound` | all outbound traffic, so EC2 can download nginx |

**Inputs:** `environment`, `vpc_id`, `ssh_cidr` → **Output:** `security_group_id`

> 💡 Each rule is its own resource instead of `ingress {}` / `egress {}` blocks inside the security group — that's what the AWS provider docs recommend now. And when Terraform creates a security group, it removes AWS's default "allow all outbound" rule, so I write the egress rule myself. Without it, EC2 can't install nginx.

### `modules/iam` — permissions for the server

| Resource | Name in code | What it does |
|----------|--------------|--------------|
| `aws_iam_role` | `nginx_ec2_role` | an identity only the EC2 service can use (trust policy) |
| `aws_iam_role_policy_attachment` | `ssm` | adds AWS's `AmazonSSMManagedInstanceCore` policy, so I can log in with Session Manager — no SSH key needed |
| `aws_iam_instance_profile` | `nginx_profile` | the "holder" that attaches the role to an EC2 instance |

**Input:** `environment` → **Output:** `instance_profile_name`

> 💡 IAM names are global in the AWS account (not per region), so the environment name goes in front: `dev-nginx-ec2-role`, `production-nginx-ec2-role`.

### `modules/ec2` — the nginx server

| Resource | Name in code | What it does |
|----------|--------------|--------------|
| `data.aws_ami` | `amazon_linux` | finds the newest Amazon Linux 2023 AMI — no hard-coded AMI ID |
| `aws_instance` | `nginx_server` | the server; `user_data` installs nginx on first boot and writes `Hello from <env> nginx` |

Extra settings on the instance:
- `metadata_options { http_tokens = "required" }` — only IMDSv2, the safer metadata service.
- `user_data_replace_on_change = true` — if I change the script, Terraform replaces the instance so the new script actually runs.
- `key_name` is optional (`default = null`) — without a key pair I use Session Manager instead of SSH.

**Inputs:** `environment`, `instance_type`, `subnet_id`, `security_group_id`, `instance_profile_name`, `key_name` → **Outputs:** `public_ip`, `instance_id`

---

## Step 3 — The Central Module: `modules/nginx-web-app`

This module has no resources of its own. It only calls the four modules and wires them together:

```hcl
module "ec2" {
  source = "../ec2"

  environment           = var.environment
  instance_type         = var.instance_type
  subnet_id             = module.vpc.public_subnet_id                 # from vpc
  security_group_id     = module.security_group.security_group_id     # from security-group
  instance_profile_name = module.iam.instance_profile_name            # from iam
  key_name              = var.key_name
}
```

**Inputs:** `environment`, `vpc_cidr`, `public_subnet_cidr`, `ssh_cidr`, `instance_type`, `key_name` → **Outputs:** `public_ip`, `instance_id`, `nginx_url`

> 💡 **Paths:** inside `nginx-web-app` the sources are `../vpc`, `../ec2`… (one level up). From an environment it's `../../modules/nginx-web-app` (two levels up).

---

## How Terraform Knows the Order (no `depends_on` everywhere)

When one resource uses another's value — like `vpc_id = aws_vpc.nginx_vpc.id` — Terraform builds the one it depends on first. The same works between modules: `module.vpc.vpc_id` passed into the security group means the VPC is built first. So I don't add `depends_on` "to be safe" — it only slows plans down and can cause needless changes.

I use `depends_on` only for a **hidden link** that no reference shows. In this project there is exactly one, in [`modules/iam/outputs.tf`](modules/iam/outputs.tf):

```hcl
output "instance_profile_name" {
  value      = aws_iam_instance_profile.nginx_profile.name
  depends_on = [aws_iam_role_policy_attachment.ssm]
}
```

The instance profile never references the SSM policy attachment, so without this, EC2 could start before the policy is attached. With `depends_on` on the output, anything that uses it (the EC2 module) also waits for the policy.

---

## Step 4 — Dev Environment

### `environments/dev/main.tf`

```hcl
# Terraform settings — version, provider and where to keep state

terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # State goes to the bootstrap bucket — only the key changes per environment
  backend "s3" {
    bucket       = "abhigna-tfstate-2026"
    key          = "dev/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
  }
}

# AWS provider — default_tags are added to every resource

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "nginx-web-app"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# The whole app — one call, the values come from terraform.tfvars

module "nginx_web_app" {
  source = "../../modules/nginx-web-app"

  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  ssh_cidr           = var.ssh_cidr
  instance_type      = var.instance_type
  key_name           = var.key_name
}
```

> ⚠️ The backend block can't use `var.` — the bucket, key and region are typed in directly. Each environment has its own `key`, so they never share a state file. If two used the same key, one would overwrite the other's state.

### `environments/dev/variables.tf`

Declares the same inputs: `region`, `environment`, `vpc_cidr`, `public_subnet_cidr`, `ssh_cidr`, `instance_type`, and `key_name` (with `default = null`).

### `environments/dev/terraform.tfvars`

```hcl
region             = "eu-west-1"
environment        = "dev"
vpc_cidr           = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
ssh_cidr           = "x.x.x.x/32" # my IP from: curl ifconfig.me
instance_type      = "t3.micro"
```

### `environments/dev/outputs.tf`

Passes up `public_ip`, `instance_id` and `nginx_url` from `module.nginx_web_app`.

### Run it

```bash
cd environments/dev
terraform init
terraform fmt -recursive ../..
terraform validate
terraform plan
terraform apply
```

✅ **Checkpoints:**

- `Plan: 13 to add` — 5 VPC + 4 security group (1 SG + 3 rules) + 3 IAM + 1 EC2.
- `terraform state list` — every address starts with `module.nginx_web_app.`, for example `module.nginx_web_app.module.ec2.aws_instance.nginx_server`.
- Wait 1–2 minutes for nginx to install, then open the `nginx_url` output in the browser (or `curl $(terraform output -raw nginx_url)`). I should see **Hello from dev nginx**.
- State is in S3, not on my laptop: `aws s3 ls s3://abhigna-tfstate-2026/dev/`.
- Session Manager works: EC2 console → my instance → **Connect** → **Session Manager** (give it 2–3 minutes after boot).

---

## Step 5 — Staging and Production

No module code is written again. I copy the four dev files and change only two things:

```bash
cd environments
cp dev/main.tf dev/variables.tf dev/outputs.tf dev/terraform.tfvars staging/
cp dev/main.tf dev/variables.tf dev/outputs.tf dev/terraform.tfvars production/
```

1. **Backend key** in `main.tf`: `staging/terraform.tfstate` / `production/terraform.tfstate`
2. **Values** in `terraform.tfvars`: `environment`, `vpc_cidr`, `public_subnet_cidr`, `instance_type` — see the table at the top.

```bash
cd staging    && terraform init && terraform apply
cd ../production && terraform init && terraform apply
```

✅ **Checkpoints:**

- Each page says `Hello from staging nginx` / `Hello from production nginx`.
- `aws s3 ls s3://abhigna-tfstate-2026/ --recursive` shows three separate state files.
- In the VPC console, the three environments are in three different VPCs — fully isolated.

---

## Step 6 — Clean Up (Order Matters)

Environments first, the backend bucket last (the environments need it to read their state).

```bash
cd environments/production && terraform destroy
cd ../staging && terraform destroy
cd ../dev && terraform destroy
```

The state bucket is protected by `prevent_destroy`, so `terraform destroy` in `bootstrap/` fails on purpose. In a real project I keep this bucket — it costs almost nothing. To remove it anyway:

1. In `bootstrap/main.tf`, delete the `lifecycle { prevent_destroy = true }` block and add `force_destroy = true` to the bucket (it's versioned, so it still holds old state versions that S3 won't delete by itself).
2. Apply that change first, then destroy:

```bash
cd ../../../bootstrap
terraform apply     # only updates force_destroy, nothing is deleted
terraform destroy
```

---

## Stretch Goals

**A. Versioned modules on GitHub.** Move `modules/` into its own repo, tag it `v1.0.0`, and point each environment at a tag:

```hcl
source = "git::https://github.com/Abhignadumpala/terraform-modules.git//nginx-web-app?ref=v1.0.0"
```

Right now every environment uses the local `../../modules` path, so a module change reaches production on its next apply. With tags, production can stay on `v1.0.0` while dev tests `v1.1.0`.

**B. More than one server.** Add `count` to the EC2 module and a second public subnet in another AZ, so staging and production can run 2–3 servers.

---

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `Missing required provider` on `validate` | Skipped `terraform init` | `terraform init` (in a module folder: `terraform init -backend=false`) |
| `terraform init` very slow / stuck on `Installing hashicorp/aws` | The AWS provider is a ~180 MB download, and Terraform only reuses the `plugin_cache_dir` copy when the folder already has a `.terraform.lock.hcl` | Copy `bootstrap/.terraform.lock.hcl` into the folder first, then `terraform init` says `Using ... from the shared cache directory` |
| `Reference to undeclared input variable` | `var.x` used in `main.tf` but not in `variables.tf` | Add the `variable "x"` block |
| `Reference to undeclared resource` | Renamed a resource but not every reference | Match `TYPE.NAME.ATTRIBUTE` everywhere |
| `Module not installed` | Added or changed a module call | `terraform init` |
| `Backend configuration changed` | Edited the backend block | `terraform init -reconfigure` |
| S3 bucket does not exist | Bootstrap not applied, or name typo | Run Step 1; match names exactly |
| `Variables may not be used here` | Used `var.` inside backend | Type the values directly |
| `Instance cannot be destroyed` | `prevent_destroy` on the state bucket | Expected — see Step 6 to remove it on purpose |
| `Error acquiring the state lock` | Another apply running, or one crashed | Wait; if it crashed, `terraform force-unlock <ID>` |
| Page doesn't load / `curl` times out | nginx still installing, or missing egress rule | Wait 2 min; check the security group rules |
| `Unsupported argument "use_lockfile"` | Terraform older than 1.11 | Upgrade Terraform |

---

## Self-Check Questions

1. Why does the backend bucket live in a separate `bootstrap/` folder?
2. Why can't the backend block use `var.environment` for the key?
3. Why do the environments call only `nginx-web-app` instead of the four modules?
4. How does Terraform know to build the VPC before the security group?
5. Where is the one `depends_on` in this project, and why is it needed there?
6. What makes a subnet "public"?
7. Why is the AMI a data block instead of a variable?
8. What is different between the dev and staging folders?

---

## Interview Version

> "I built an nginx web app on AWS with Terraform, split into four small reusable modules — VPC, security group, IAM, and EC2 — plus one central module that wires them together by passing outputs into inputs, like the VPC ID into the security group. Each environment — dev, staging, production — is a tiny root module that makes one call to that central module with its own tfvars. State is stored remotely in S3 with native locking and a separate key per environment, so the environments are fully isolated, and the state bucket is created once in a bootstrap folder with versioning and `prevent_destroy`. Terraform works out the build order from references; I only use `depends_on` for the one hidden link, where the EC2 instance has to wait for the IAM policy attachment. The server gets an SSM role, so I connect with Session Manager instead of opening SSH to the world, and the AMI comes from a data source, so there are no hard-coded IDs."

---

## Official Docs

- [Terraform block & `required_providers`](https://developer.hashicorp.com/terraform/language/block/terraform)
- [S3 backend (incl. `use_lockfile`)](https://developer.hashicorp.com/terraform/language/backend/s3)
- [Modules](https://developer.hashicorp.com/terraform/language/modules) and [module sources](https://developer.hashicorp.com/terraform/language/modules/sources)
- [Data sources](https://developer.hashicorp.com/terraform/language/data-sources)
- [`depends_on`](https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on)
- [Provider plugin cache](https://developer.hashicorp.com/terraform/cli/config/config-file#provider-plugin-cache)
- AWS provider: [`aws_vpc`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc), [`aws_security_group`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group), [`aws_vpc_security_group_ingress_rule`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule), [`aws_instance`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance), [`aws_iam_role`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role), [`aws_iam_instance_profile`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile), [`aws_ami` data source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami)
