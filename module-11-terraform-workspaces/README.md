# Terraform Workspaces: Managing Multiple Environments

## Table of Contents

1. [Introduction](#introduction)
2. [What is a Terraform Workspace?](#what-is-a-terraform-workspace)
3. [Problem Without Workspaces](#problem-without-workspaces)
4. [Solution With Workspaces](#solution-with-workspaces)
5. [Creating Workspaces](#creating-workspaces)
6. [Parameterizing Configuration](#parameterizing-configuration)
7. [Switching Workspaces](#switching-workspaces)
8. [Real-World Example](#real-world-example)
9. [State Management](#state-management)
10. [Best Practices](#best-practices)
11. [Key Takeaways](#key-takeaways)

---

## Introduction

Managing multiple environments (dev, staging, prod) in Terraform can be challenging. Without workspaces, you might duplicate configuration files or create separate directories, leading to maintenance headaches.

**Terraform workspaces solve this problem** by allowing you to manage multiple environments using a single configuration directory with isolated state files.

### Key Benefits

✅ One configuration directory for multiple environments  
✅ Separate state files (no cross-contamination)  
✅ Easy environment switching  
✅ Reduced code duplication  
✅ Improved maintainability  

---

## What is a Terraform Workspace?

A **workspace** is an isolated state environment within the same configuration directory.

### Key Concept

```
Single Configuration + Multiple Workspaces = Multiple Environments
```

### How It Works

- Each workspace has its own **state file**
- Workspaces share the same **configuration code**
- You can switch between workspaces instantly
- Changes in one workspace don't affect others

---

## Problem Without Workspaces

### Scenario: Two Projects

You need to create EC2 instances for two projects:
- **Project A** in AWS CA Central 1 region
- **Project B** in AWS CA Central 1 region

### Without Workspaces (Bad Approach)

You might create separate directories:

```
terraform/
├── ProjectA/
│   ├── main.tf
│   ├── provider.tf
│   └── terraform.tfstate
└── ProjectB/
    ├── main.tf          (duplicated!)
    ├── provider.tf      (duplicated!)
    └── terraform.tfstate
```

**Problems:**
- Code duplication
- Hard to maintain
- Changes needed in multiple places
- Configuration drift risk

### ProjectA main.tf

```hcl
resource "aws_instance" "projectA" {
  ami           = "ami-0edab43b6fa892279"
  instance_type = "t2.micro"
  tags = {
    Name = "ProjectA"
  }
}
```

### ProjectB main.tf (Duplicated)

```hcl
resource "aws_instance" "projectB" {
  ami           = "ami-0c2f25c1f66a1ff4d"
  instance_type = "t2.micro"
  tags = {
    Name = "ProjectB"
  }
}
```

---

## Solution With Workspaces

### Better Approach

Use **one configuration directory** with **multiple workspaces**:

```
terraform/
├── main.tf
├── variables.tf
├── provider.tf
└── terraform.tfstate.d/
    ├── ProjectA/
    │   └── terraform.tfstate
    └── ProjectB/
        └── terraform.tfstate
```

**Benefits:**
- Single configuration file
- Easy to update
- Isolated state files
- Professional approach

---

## Creating Workspaces

### List Current Workspaces

```bash
terraform workspace list
```

**Output:**
```
  default
```

By default, Terraform has one workspace called `default`.

### Create New Workspace

```bash
terraform workspace new ProjectA
```

**Output:**
```
Created and switched to workspace "ProjectA"!

You're now on a new, empty workspace. Workspaces isolate their 
state, so if you run "terraform plan" Terraform will not see any 
existing state for this configuration.
```

### Verify Workspace Created

```bash
terraform workspace list
```

**Output:**
```
  default
* ProjectA
```

The asterisk (`*`) shows the **active workspace**.

### Create Second Workspace

```bash
terraform workspace new ProjectB
```

### List All Workspaces

```bash
terraform workspace list
```

**Output:**
```
  default
  ProjectA
* ProjectB
```

---

## Parameterizing Configuration

To use one configuration for multiple environments, you need **variables**.

### Step 1: Create variables.tf

```hcl
// variables.tf

variable "region" {
  description = "AWS region"
  default     = "ca-central-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"
}

variable "ami" {
  description = "AMI IDs for each project"
  type        = map(string)
  default = {
    "ProjectA" = "ami-0edab43b6fa892279"
    "ProjectB" = "ami-0c2f25c1f66a1ff4d"
  }
}
```

### Step 2: Update main.tf to Use Variables

```hcl
// main.tf

resource "aws_instance" "project" {
  ami           = lookup(var.ami, terraform.workspace)
  instance_type = var.instance_type
  
  tags = {
    Name = terraform.workspace
  }
}
```

### Key Variables Explained

| Variable | Meaning |
|----------|---------|
| `terraform.workspace` | Current active workspace name |
| `lookup(var.ami, terraform.workspace)` | Get AMI for current workspace |

### How It Works

When you're in **ProjectA** workspace:
- `terraform.workspace` = "ProjectA"
- `lookup(var.ami, "ProjectA")` = "ami-0edab43b6fa892279"
- Tags show `Name = ProjectA`

When you're in **ProjectB** workspace:
- `terraform.workspace` = "ProjectB"
- `lookup(var.ami, "ProjectB")` = "ami-0c2f25c1f66a1ff4d"
- Tags show `Name = ProjectB`

### Verify in Terraform Console

```bash
terraform console
```

Inside console:

```
> terraform.workspace
ProjectA

> lookup(var.ami, terraform.workspace)
"ami-0edab43b6fa892279"

> exit
```

---

## Switching Workspaces

### Switch to a Workspace

```bash
terraform workspace select ProjectA
```

**Output:**
```
Switched to workspace "ProjectA".
```

### Current Workspace

```bash
terraform workspace show
```

**Output:**
```
ProjectA
```

### Switch Back to Default

```bash
terraform workspace select default
```

---

## Real-World Example

### Directory Structure

```
terraform/
├── main.tf
├── variables.tf
├── provider.tf
└── terraform.tfstate.d/
    ├── ProjectA/
    │   └── terraform.tfstate
    └── ProjectB/
        └── terraform.tfstate
```

### Complete Configuration

**provider.tf:**
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
  region = var.region
}
```

**variables.tf:**
```hcl
variable "region" {
  default = "ca-central-1"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "ami" {
  type = map(string)
  default = {
    "ProjectA" = "ami-0edab43b6fa892279"
    "ProjectB" = "ami-0c2f25c1f66a1ff4d"
  }
}
```

**main.tf:**
```hcl
resource "aws_instance" "project" {
  ami           = lookup(var.ami, terraform.workspace)
  instance_type = var.instance_type
  
  tags = {
    Name        = terraform.workspace
    Environment = terraform.workspace
  }
}

output "instance_id" {
  value       = aws_instance.project.id
  description = "Instance ID of the project"
}
```

### Workflow

```bash
# Initialize Terraform
terraform init

# Create ProjectA workspace
terraform workspace new ProjectA

# Plan for ProjectA
terraform plan
# Shows: ami-0edab43b6fa892279, Name = ProjectA

# Apply for ProjectA
terraform apply

# Switch to ProjectB
terraform workspace new ProjectB

# Plan for ProjectB
terraform plan
# Shows: ami-0c2f25c1f66a1ff4d, Name = ProjectB

# Apply for ProjectB
terraform apply

# List all workspaces
terraform workspace list

# Switch back to ProjectA
terraform workspace select ProjectA

# Show ProjectA state
terraform show
```

---

## State Management

### State File Structure

After applying configurations, Terraform creates:

```
$ tree terraform.tfstate.d/
terraform.tfstate.d/
├── ProjectA
│   └── terraform.tfstate
└── ProjectB
    └── terraform.tfstate
```

### Default Workspace State

The default workspace state is stored at root:

```
terraform.tfstate
```

### State Isolation

Each workspace has **isolated state**:

- Changes in ProjectA workspace don't affect ProjectB
- Each workspace maintains its own resources
- No accidental cross-contamination

### Viewing State

```bash
# View current workspace state
terraform show

# Inspect ProjectA state
terraform workspace select ProjectA
terraform show

# Inspect ProjectB state
terraform workspace select ProjectB
terraform show
```

---

## Best Practices

### 1. Use Descriptive Workspace Names

```bash
# Good
terraform workspace new production
terraform workspace new staging
terraform workspace new development

# Avoid
terraform workspace new proj1
terraform workspace new env2
```

### 2. Use Variables for Environment-Specific Values

```hcl
// Good approach
variable "instance_count" {
  type = map(number)
  default = {
    production = 3
    staging    = 2
    development = 1
  }
}

resource "aws_instance" "app" {
  count = var.instance_count[terraform.workspace]
}

// Avoid hardcoding
resource "aws_instance" "app" {
  count = 3  # Don't do this
}
```

### 3. Document Workspace Purpose

```hcl
// workspaces.md
# Terraform Workspaces

- **production** - Production environment (3 instances)
- **staging** - Staging environment (2 instances)  
- **development** - Development environment (1 instance)
```

### 4. Use `.tfvars` Files per Environment

```bash
terraform apply -var-file="production.tfvars"
terraform apply -var-file="staging.tfvars"
```

### 5. Store State Remotely

```hcl
// For production use, store state in S3
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "env/${terraform.workspace}/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

### 6. Use Consistent Naming

```bash
# Consistent workspace names
terraform workspace new prod
terraform workspace new staging
terraform workspace new dev

# NOT RECOMMENDED
terraform workspace new production-env
terraform workspace new stage
terraform workspace new development
```

---

## Common Workspace Operations

### Create and Apply

```bash
# Create workspace
terraform workspace new staging

# Plan changes
terraform plan -out=staging.tfplan

# Apply changes
terraform apply staging.tfplan

# Confirm
terraform show
```

### Switch Environments

```bash
# List workspaces
terraform workspace list

# Switch to production
terraform workspace select production

# Verify switch
terraform workspace show
```

### Destroy Environment

```bash
# Switch to environment
terraform workspace select development

# Destroy resources
terraform destroy

# Workspace still exists (empty)
terraform workspace list

# Optional: Delete workspace
# Note: Can't delete current workspace
terraform workspace select default
# terraform workspace delete development (if needed)
```

### Export State Info

```bash
# Show current workspace
terraform workspace show

# List all workspaces
terraform workspace list

# View resources in current workspace
terraform state list

# Show specific resource
terraform state show aws_instance.project
```

---

## Workspace Limitations

⚠️ **Things to Know:**

1. **Can't delete active workspace**
   ```bash
   # This fails if you're in staging
   terraform workspace delete staging
   
   # Solution: Switch first
   terraform workspace select default
   terraform workspace delete staging
   ```

2. **Workspaces are not for security**
   - Use IAM roles for security, not workspaces
   - Anyone with access to code has access to all workspaces

3. **Remote state is recommended**
   - Local state files can be lost
   - Use S3, Terraform Cloud, or other backends for production

---

## Workspaces vs Modules

| Feature | Workspaces | Modules |
|---------|-----------|---------|
| **Purpose** | Manage environments | Reuse code components |
| **Example** | dev, staging, prod | vpc, security_group, rds |
| **Isolation** | State separated | Code reused |
| **Use Together** | Yes! | Yes! |

---

## Key Takeaways

✅ **Workspaces isolate state** for multiple environments  
✅ **Use one configuration** with `terraform.workspace` variable  
✅ **Separate state files** prevent cross-contamination  
✅ **Easy switching** between environments with `select`  
✅ **Use variables** to parameterize per-environment values  
✅ **Store remote state** for production (S3, Terraform Cloud)  
✅ **Combine with modules** for professional infrastructure  

---

## Common Commands Reference

| Command | Purpose |
|---------|---------|
| `terraform workspace new <name>` | Create new workspace |
| `terraform workspace list` | List all workspaces |
| `terraform workspace select <name>` | Switch workspace |
| `terraform workspace show` | Show current workspace |
| `terraform workspace delete <name>` | Delete workspace |
| `terraform plan` | Plan for current workspace |
| `terraform apply` | Apply for current workspace |
| `terraform destroy` | Destroy resources in workspace |

---

## Workflow Example

```bash
# Initialize project
terraform init

# Create development workspace
terraform workspace new development
terraform plan
terraform apply

# Create staging workspace
terraform workspace new staging
terraform plan
terraform apply

# Create production workspace
terraform workspace new production
terraform plan
terraform apply

# List all environments
terraform workspace list

# Switch between environments
terraform workspace select staging
terraform show

terraform workspace select production
terraform show

# When done with development
terraform workspace select development
terraform destroy

terraform workspace select default
terraform workspace delete development
```

---

## Terraform Modules vs Workspaces

### Definitions

#### What is a Module?

A **module** is like a pre-built template for infrastructure. It contains reusable Terraform code for common components.

Think of it like a **LEGO block**. You build one VPC block once, then use it in many different projects.

**Example:** 
- Write VPC configuration once (VPC + subnets + routes + security groups)
- Use the same VPC module in Project A, Project B, and Project C
- No need to copy-paste code

#### What is a Workspace?

A **workspace** is a way to keep different environments separate using the same code.

Think of it like having **multiple copies of the same blueprint**. Same design, different buildings.

**Example:**
- You have one Terraform configuration file
- Create 3 workspaces: dev, staging, production
- When you switch to `dev`, you create dev resources
- When you switch to `production`, you create production resources
- Each environment has its own separate state file (no mixing up resources)

---

### Quick Comparison Table

| Aspect | Modules | Workspaces |
|--------|---------|-----------|
| **What is it?** | Reusable code container | State separation mechanism |
| **Purpose** | Build & reuse infrastructure components | Manage multiple environments |
| **Problem it solves** | Code duplication across projects | Configuration repetition within project |
| **Example** | VPC, Security Group, RDS database | dev, staging, production |
| **Scope** | Code reuse | State isolation |
| **Use across** | Multiple projects | Same project |
| **How many?** | Multiple modules per project | Multiple workspaces per project |

---

### When to Use Each

**Use Modules When:**
- Building reusable infrastructure components (VPC, databases, load balancers)
- You want DRY (Don't Repeat Yourself) code across multiple projects
- You need standardized infrastructure patterns that teams can share
- Managing complex systems with many interconnected resources

**Use Workspaces When:**
- Managing multiple environments from one codebase (dev, staging, prod)
- Your infrastructure setup is the same across environments
- You need separate state files to prevent cross-environment issues
- You want to quickly switch between and deploy to different environments

### Real Example

```bash
# Modules = Components
module "vpc" {
  source = "./modules/vpc"
}

module "security_group" {
  source = "./modules/security_group"
}

# Workspaces = Environments
terraform workspace new dev
terraform apply  # Creates dev infrastructure

terraform workspace new prod
terraform apply  # Creates prod infrastructure (same code, different state)
```

### Combine Both (Best Practice)

```bash
# Use modules for components
module "vpc" { ... }
module "rds" { ... }

# Use workspaces for environments
terraform workspace select production
terraform apply

terraform workspace select staging
terraform apply
```

### Summary

```
Modules     = "How do I structure reusable code?"
Workspaces  = "How do I manage different environments?"

Use BOTH together for professional infrastructure! ✅
```

---

## Resources

- [Terraform Workspaces Documentation](https://www.terraform.io/docs/state/workspaces.html)
- [Terraform State Management](https://www.terraform.io/docs/state/)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)


