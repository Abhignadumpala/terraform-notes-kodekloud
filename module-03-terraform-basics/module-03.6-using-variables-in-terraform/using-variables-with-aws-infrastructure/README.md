# 3.6: Using Variables in Terraform with AWS Infrastructure

> Master all techniques to pass input variables in Terraform including default values, command line input, environment variables, and variable definition precedence. Bridge the gap between Terraform variable theory and real AWS production deployments.

---

## What are Terraform Variables?

Variables in Terraform allow you to:
- ✅ Avoid hardcoding values
- ✅ Reuse configurations across environments
- ✅ Make configurations flexible and maintainable
- ✅ Pass dynamic values at runtime

Think of them like function parameters in programming.

---

## Table of Contents
1. [What are Terraform Variables?](#what-are-terraform-variables)
2. [5 Ways to Provide Variable Values](#5-ways-to-provide-variable-values)
3. [Variable Definition Precedence](#variable-definition-precedence)
4. [Real-World AWS Scenarios](#real-world-aws-scenarios)
5. [Key Takeaways](#key-takeaways)

---

## 5 Ways to Provide Variable Values

### Method 1: Default Values with Variable Blocks

### When to Use with AWS:
- ✅ Development/Sandbox environments
- ✅ Testing and learning (like your homelab)
- ✅ Internal tools and utilities
- ✅ Non-critical resources
- ❌ NOT for production infrastructure
- ❌ NOT for sensitive configurations

### AWS Example: Simple EC2 Instance for Development

**File: `variables.tf`**
```hcl
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"  # Non-sensitive default
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"   # Free tier eligible for testing
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}

variable "instance_name" {
  description = "Name tag for the instance"
  type        = string
  default     = "dev-webserver"
}
```

**File: `main.tf`**
```hcl
provider "aws" {
  region = var.aws_region
}

resource "aws_instance" "web_server" {
  ami           = "ami-0c55b159cbfafe1f0"  # Amazon Linux 2
  instance_type = var.instance_type
  
  tags = {
    Name        = var.instance_name
    Environment = var.environment
  }
}
```

### Real-World Scenario:
You're a DevOps engineer learning AWS, spinning up instances in your personal AWS sandbox account for testing Terraform configurations.

**Command:**
```bash
$ terraform init
$ terraform plan      # Uses all defaults
$ terraform apply     # Creates t2.micro in us-east-1
```

### ✅ Pros for AWS Dev:
- Immediate testing without configuration setup
- Quick validation of Terraform syntax
- Perfect for learning resources
- Free tier eligible (t2.micro)
- No accidental production changes

### ❌ Cons for Production:
- Can't change without code edits
- Easy to accidentally deploy dev defaults to prod
- No environment separation
- Hardcoded values cause team friction

---

## Method 2: Interactive Prompts and Command-Line Input

**Use Case:** CI/CD Automation

### When to Use with AWS:
- ✅ Automated deployments (GitHub Actions, GitLab CI, Jenkins)
- ✅ One-time infrastructure changes
- ✅ Terraform Cloud/Enterprise pipelines
- ✅ Dynamic values from CI/CD systems
- ✅ Overriding defaults in specific cases

### AWS Example: Deploying to Multiple AWS Accounts via CI/CD

**File: `variables.tf`**
```hcl
variable "aws_region" {
  type = string
}

variable "instance_count" {
  type = number
}

variable "instance_type" {
  type = string
}

variable "environment" {
  type = string
}

variable "owner_email" {
  type = string
}

variable "cost_center" {
  type = string
}
```

**File: `main.tf`**
```hcl
provider "aws" {
  region = var.aws_region
}

resource "aws_instance" "app_servers" {
  count         = var.instance_count
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = var.instance_type
  
  tags = {
    Name        = "${var.environment}-app-${count.index + 1}"
    Environment = var.environment
    Owner       = var.owner_email
    CostCenter  = var.cost_center
  }
}
```

### Real-World CI/CD Scenario: GitHub Actions

**File: `.github/workflows/deploy.yml`**
```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v2
      
      - name: Deploy to Dev
        run: |
          terraform init
          terraform plan \
            -var "aws_region=us-east-1" \
            -var "instance_count=2" \
            -var "instance_type=t2.micro" \
            -var "environment=development" \
            -var "owner_email=devops@company.com" \
            -var "cost_center=ENGINEERING"
          terraform apply -auto-approve
      
      - name: Deploy to Staging
        run: |
          terraform plan \
            -var "aws_region=us-west-2" \
            -var "instance_count=3" \
            -var "instance_type=t2.small" \
            -var "environment=staging" \
            -var "owner_email=devops@company.com" \
            -var "cost_center=ENGINEERING"
          terraform apply -auto-approve
```

### Real-World Example: Jenkins Deployment

```bash
#!/bin/bash
# jenkins-deploy.sh

# Extract from Jenkins environment variables
REGION="${AWS_REGION}"
INSTANCE_TYPE="${INSTANCE_TYPE}"
ENVIRONMENT="${DEPLOY_ENV}"
OWNER="${BUILD_USER_EMAIL}"
COST_CENTER="${PROJECT_COST_CENTER}"

terraform init
terraform apply \
  -var "aws_region=${REGION}" \
  -var "instance_count=2" \
  -var "instance_type=${INSTANCE_TYPE}" \
  -var "environment=${ENVIRONMENT}" \
  -var "owner_email=${OWNER}" \
  -var "cost_center=${COST_CENTER}" \
  -auto-approve
```

### ✅ Pros for AWS Automation:
- **HIGHEST PRIORITY** — always overrides other sources
- Perfect for CI/CD pipelines
- Dynamic values from CI/CD systems
- Fully automated, no manual intervention
- Clear audit trail in CI/CD logs
- Easy to see exact values being deployed

### ❌ Cons:
- Command line gets very long with many variables
- Hard to read and maintain
- Mistakes can cause deployment failures
- Not suitable for secrets

---

## Method 3: Environment Variables Setup

**Use Case:** Secrets & API Keys

### When to Use with AWS:
- ✅ AWS credentials (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
- ✅ Database passwords
- ✅ API keys and tokens
- ✅ GitHub/GitLab personal access tokens
- ✅ Sensitive configuration data
- ✅ CI/CD systems with secret vaults
- ❌ NOT for non-sensitive values (too messy)

### AWS Example: Deploying RDS Database with Secrets

**File: `variables.tf`**
```hcl
variable "db_master_username" {
  description = "RDS master username"
  type        = string
  sensitive   = true  # Prevents logging the value
}

variable "db_master_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Initial database name"
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t2.micro"
}
```

**File: `main.tf`**
```hcl
provider "aws" {
  region = "us-east-1"
}

resource "aws_db_instance" "production" {
  identifier     = "prod-postgres-db"
  engine         = "postgres"
  engine_version = "13.7"
  instance_class = var.db_instance_class
  
  # Sensitive variables — passed via environment
  username = var.db_master_username
  password = var.db_master_password
  db_name  = var.db_name
  
  allocated_storage = 20
  skip_final_snapshot = false
  
  tags = {
    Name        = "production-database"
    Environment = "production"
  }
}

output "db_endpoint" {
  value       = aws_db_instance.production.endpoint
  description = "RDS database endpoint"
}
```

### Real-World Scenario: Local Development

```bash
# Developer machine setup (NOT committed to git!)
export TF_VAR_db_master_username="admin"
export TF_VAR_db_master_password="SuperSecure!Pass2024"
export TF_VAR_db_name="production_db"

# Now safe to run terraform
terraform apply
# Password never appears in logs!
```

### Real-World Scenario: CI/CD with GitHub Secrets

**File: `.github/workflows/deploy-database.yml`**
```yaml
name: Deploy RDS Database

on:
  push:
    branches: [main]
    paths:
      - 'database/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    env:
      TF_VAR_db_master_username: ${{ secrets.DB_USERNAME }}
      TF_VAR_db_master_password: ${{ secrets.DB_PASSWORD }}
      TF_VAR_db_name: "production_db"
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    
    steps:
      - uses: actions/checkout@v2
      
      - name: Deploy Database
        run: |
          cd database/
          terraform init
          terraform apply -auto-approve
```

### Real-World Scenario: AWS Systems Manager Parameter Store

```bash
#!/bin/bash
# Get secrets from AWS Parameter Store instead of hardcoding

DB_PASSWORD=$(aws ssm get-parameter \
  --name "/prod/rds/master_password" \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text)

export TF_VAR_db_master_password="$DB_PASSWORD"

terraform apply -auto-approve
```

### ✅ Pros for AWS Production:
- Secrets never logged or visible in code
- Perfect for sensitive data (passwords, keys, tokens)
- Can be set in CI/CD secret vaults
- Works with AWS Secrets Manager
- Works with Parameter Store
- Clean, organized approach
- Cross-platform (Linux, Mac, Windows)

### ❌ Cons:
- Need setup before running terraform
- Forgotten between sessions
- Not persistent across reboots
- Variables can leak in shell history

---

## Method 4: Using Variable Definition Files

**Use Case:** Multi-Environment AWS

### When to Use with AWS:
- ✅ Managing dev, staging, production environments
- ✅ Organizing many variables
- ✅ Non-sensitive configuration values
- ✅ Environment-specific AWS account IDs
- ✅ Region-specific settings
- ✅ Instance types per environment
- ❌ NOT for passwords/secrets (use env vars instead)

### AWS Example: Multi-Environment Infrastructure

**Project Structure:**
```
terraform/
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars          # Shared/default values
├── dev.tfvars                # Development environment
├── staging.tfvars            # Staging environment
└── prod.tfvars               # Production environment
```

**File: `variables.tf`**
```hcl
variable "aws_region" {
  type = string
}

variable "environment" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "instance_count" {
  type = number
}

variable "enable_monitoring" {
  type = bool
}

variable "backup_retention_days" {
  type = number
}

variable "enable_public_ip" {
  type = bool
}

variable "vpc_cidr" {
  type = string
}
```

**File: `dev.tfvars` — Development**
```hcl
aws_region            = "us-east-1"
environment           = "development"
instance_type         = "t2.micro"        # Cheap for dev
instance_count        = 1                 # Single instance
enable_monitoring     = false             # Save costs
backup_retention_days = 3                 # Minimal backups
enable_public_ip      = true              # For easy access
vpc_cidr              = "10.0.0.0/16"
```

**File: `staging.tfvars` — Staging**
```hcl
aws_region            = "us-west-2"
environment           = "staging"
instance_type         = "t2.small"        # Moderate for testing
instance_count        = 2                 # Load balancing
enable_monitoring     = true              # Monitor for issues
backup_retention_days = 7                 # Weekly retention
enable_public_ip      = false             # Internal only
vpc_cidr              = "10.1.0.0/16"
```

**File: `prod.tfvars` — Production**
```hcl
aws_region            = "us-east-1"
environment           = "production"
instance_type         = "t2.medium"       # Proper sizing
instance_count        = 3                 # High availability
enable_monitoring     = true              # Always monitor
backup_retention_days = 30                # Monthly retention
enable_public_ip      = false             # Behind ALB only
vpc_cidr              = "10.2.0.0/16"
```

**File: `main.tf`**
```hcl
provider "aws" {
  region = var.aws_region
}

resource "aws_instance" "app_servers" {
  count                = var.instance_count
  ami                  = "ami-0c55b159cbfafe1f0"
  instance_type        = var.instance_type
  associate_public_ip_address = var.enable_public_ip
  
  tags = {
    Name        = "${var.environment}-app-${count.index + 1}"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu" {
  count              = var.enable_monitoring ? 1 : 0
  alarm_name         = "${var.environment}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
}
```

### Real-World Deployment Commands:

```bash
# Development deployment
$ terraform apply -var-file="dev.tfvars"

# Staging deployment
$ terraform apply -var-file="staging.tfvars"

# Production deployment
$ terraform apply -var-file="prod.tfvars"
```

### Real-World Scenario: GitOps with Multiple Environments

**File: `.gitlab-ci.yml`**
```yaml
stages:
  - plan
  - apply

variables:
  TF_ROOT: ${CI_PROJECT_DIR}/terraform

plan:dev:
  stage: plan
  script:
    - cd $TF_ROOT
    - terraform init
    - terraform plan -var-file="dev.tfvars" -out=tfplan
  artifacts:
    paths:
      - $TF_ROOT/tfplan

apply:dev:
  stage: apply
  script:
    - cd $TF_ROOT
    - terraform apply tfplan
  when: manual
  only:
    - develop

plan:prod:
  stage: plan
  script:
    - cd $TF_ROOT
    - terraform plan -var-file="prod.tfvars" -out=tfplan
  artifacts:
    paths:
      - $TF_ROOT/tfplan

apply:prod:
  stage: apply
  script:
    - cd $TF_ROOT
    - terraform apply tfplan
  when: manual
  only:
    - main
```

### ✅ Pros for AWS Multi-Environment:
- Centralized and organized
- Easy to manage environment-specific configs
- Perfect for dev/staging/prod separation
- Readable HCL format
- Easy to version control
- Clear separation of concerns
- Team members can easily understand which file is for which environment

### ❌ Cons:
- Multiple files to maintain
- Easy to mix up which file is for which environment
- Files can get large with many variables
- Risk of committing secrets if not careful
- Requires discipline to keep organized

---

## Method 5: Combination Approach - Multiple Sources

**Use Case:** Production Setup

### When to Use:
- ✅ Enterprise production infrastructure
- ✅ Complex multi-team deployments
- ✅ Maximum flexibility and control
- ✅ Handling different scenarios

### Real-World AWS Production Architecture

**Project Structure:**
```
terraform/
├── main.tf                    # Infrastructure definition
├── variables.tf               # Variable definitions
├── outputs.tf                 # Output values
├── terraform.tfvars           # Shared/default non-sensitive values
├── terraform.tfvars.json      # Can also use JSON format
├── dev.tfvars                 # Development environment
├── staging.tfvars             # Staging environment
├── prod.tfvars                # Production environment
├── .gitignore                 # Prevent secret leaks
└── .gitlab-ci.yml             # CI/CD configuration
```

**File: `.gitignore`**
```bash
# Don't commit secrets!
*.tfvars         # Can contain secrets
*.tfvars.json
.terraform/
.terraform.lock.hcl
terraform.tfstate
terraform.tfstate.*
*.pem             # Private keys
crash.log
crash.*.log
```

**Real-World Production Flow:**

```bash
# Step 1: Start with environment-specific file
$ terraform apply -var-file="prod.tfvars" \
  -var "instance_count=5"                    # Override for this deployment
  
# Terraform uses (in order of priority):
# 1. Environment variables (TF_VAR_*) — for AWS credentials & secrets
# 2. terraform.tfvars — for shared non-sensitive defaults
# 3. *.auto.tfvars — for auto-loaded custom files
# 4. prod.tfvars — for environment-specific values (from -var-file)
# 5. -var flag — for temporary overrides (HIGHEST PRIORITY)
```

### Real-World AWS Company Deployment Process

**Scenario:** Large AWS company deploying to 5 AWS accounts across 3 regions

**File: `terraform.tfvars` — Shared Defaults**
```hcl
# These apply everywhere
enable_detailed_monitoring = true
enable_backup             = true
backup_retention_days     = 30
company_name              = "MyCompany"
cost_allocation_tags      = true
```

**File: `prod.tfvars` — Production**
```hcl
# Production-specific overrides
aws_region              = "us-east-1"
environment             = "production"
instance_type           = "t3.large"
instance_count          = 10
enable_public_ip        = false
multi_az                = true
enable_monitoring       = true
backup_retention_days   = 90
enable_cloudtrail       = true
```

**File: `deploy.sh` — Actual Deployment Script**
```bash
#!/bin/bash
set -e

ENVIRONMENT=${1:-staging}
AWS_ACCOUNT_ID=${2:-"123456789012"}
AWS_REGION=${3:-us-east-1}
TERRAFORM_VERSION="1.5.0"

# Step 1: Setup environment variables for AWS credentials
export AWS_ACCESS_KEY_ID=$(aws ssm get-parameter \
  --name "/terraform/${ENVIRONMENT}/aws_access_key" \
  --with-decryption --query 'Parameter.Value' --output text)

export AWS_SECRET_ACCESS_KEY=$(aws ssm get-parameter \
  --name "/terraform/${ENVIRONMENT}/aws_secret_key" \
  --with-decryption --query 'Parameter.Value' --output text)

# Step 2: Setup other sensitive environment variables
export TF_VAR_db_password=$(aws ssm get-parameter \
  --name "/${ENVIRONMENT}/rds/master_password" \
  --with-decryption --query 'Parameter.Value' --output text)

export TF_VAR_api_key=$(aws secretsmanager get-secret-value \
  --secret-id "${ENVIRONMENT}/api_key" \
  --query SecretString --output text)

# Step 3: Initialize Terraform
terraform init \
  -backend-config="bucket=my-company-terraform-state" \
  -backend-config="key=${ENVIRONMENT}/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}"

# Step 4: Plan with environment file + CLI overrides
terraform plan \
  -var-file="${ENVIRONMENT}.tfvars" \
  -var="aws_region=${AWS_REGION}" \
  -var="aws_account_id=${AWS_ACCOUNT_ID}" \
  -out=tfplan

# Step 5: Ask for approval
read -p "Review plan above. Apply? (yes/no): " APPROVE
if [ "$APPROVE" != "yes" ]; then
  echo "Deployment cancelled"
  exit 1
fi

# Step 6: Apply
terraform apply tfplan

# Step 7: Output important values
terraform output -json > ${ENVIRONMENT}-outputs.json

echo "✅ Deployment complete!"
echo "Outputs saved to ${ENVIRONMENT}-outputs.json"
```

### Real-World Usage:

```bash
# Development deployment
$ bash deploy.sh development 111111111111 us-east-1

# Staging deployment
$ bash deploy.sh staging 222222222222 us-west-2

# Production deployment (with extra checks)
$ bash deploy.sh production 333333333333 us-east-1
# Asks for manual approval before applying!
```

### ✅ Pros for AWS Enterprise:
- Maximum flexibility
- Handles complex scenarios
- Clear precedence rules
- Secrets kept separate from code
- Environment-specific configurations
- Easy to audit and debug
- Suitable for large teams
- Works with all deployment scenarios

### ❌ Cons:
- More complex to understand
- Multiple configuration sources to manage
- Can be confusing for new team members
- Requires discipline and documentation
- Hard to debug if something goes wrong

---

## Variable Definition Precedence

Terraform allows you to set variable values from multiple sources. When the same variable is defined in multiple places, Terraform uses a specific order of precedence to determine which value to apply.

### Example Scenario:

Consider a variable `filename` defined in multiple places:

* **Environment Variable:**
  ```bash
  $ export TF_VAR_filename="/root/cats.txt"
  ```

* **terraform.tfvars File:**
  ```hcl
  filename = "/root/pets.txt"
  ```

* **File Ending with .auto.tfvars:**
  ```hcl
  filename = "/root/mypet.txt"
  ```

* **Command-Line Flag:**
  ```bash
  $ terraform apply -var "filename=/root/best-pet.txt"
  ```

### Configuration Files:

```hcl
# main.tf
resource "local_file" "pet" {
  filename = var.filename
}

# variables.tf
variable "filename" {
  type = string
}
```

### Terraform Precedence Order (Lowest to Highest Priority):

| Precedence Level | Source | Example | Value Used |
|---|---|---|---|
| 1 (Lowest) | Environment variables (`TF_VAR_`) | `export TF_VAR_filename="/root/cats.txt"` | `/root/cats.txt` |
| 2 | terraform.tfvars file | `filename = "/root/pets.txt"` | `/root/pets.txt` |
| 3 | Files ending with `.auto.tfvars` or `.auto.tfvars.json` | `filename = "/root/mypet.txt"` | `/root/mypet.txt` |
| 4 (Highest) | Command-line flags (`-var` or `-var-file`) | `terraform apply -var "filename=/root/best-pet.txt"` | `/root/best-pet.txt` |

### Result:

Since the command-line flag (`-var`) has the **HIGHEST precedence**, the variable `filename` will ultimately be assigned the value `/root/best-pet.txt`.

### Real AWS Example: Overriding Production Defaults

```bash
# Base configuration uses prod.tfvars (3 instances)
# But temporarily need 5 instances for load testing
$ terraform apply -var-file="prod.tfvars" -var "instance_count=5"

# Terraform uses: instance_count=5 (from -var flag, HIGHEST priority)
# Everything else from prod.tfvars
```

### Key Principle:

**Remember:** The order in which variable values are applied ensures predictability in your deployment. This hierarchy allows you to override defaults and maintain control over your configuration settings.

---

## Real-World AWS Scenarios

### Scenario 1: Auto-Scaling Web Application

**Requirement:** Deploy web app to 3 environments with different scaling policies

**File: `variables.tf`**
```hcl
variable "min_size" {
  type = number
}

variable "max_size" {
  type = number
}

variable "desired_capacity" {
  type = number
}

variable "health_check_type" {
  type = string
}
```

**File: `dev.tfvars`**
```hcl
min_size            = 1
max_size            = 2
desired_capacity    = 1
health_check_type   = "ELB"
```

**File: `prod.tfvars`**
```hcl
min_size            = 3
max_size            = 10
desired_capacity    = 5
health_check_type   = "ELB"
```

```bash
# Deploy with appropriate scaling
$ terraform apply -var-file="prod.tfvars"
# Creates ASG with 3-10 instances for production
```

### Scenario 2: Database Backup Strategy

**Requirement:** Different backup retention for each environment

```bash
# Development: minimal backups
$ terraform apply -var-file="dev.tfvars" \
  -var "backup_retention_days=3"

# Production: long-term retention
$ terraform apply -var-file="prod.tfvars" \
  -var "backup_retention_days=90"
```

### Scenario 3: Network Configuration

**Requirement:** Deploy to different VPCs with different CIDR blocks

```bash
# Using .tfvars files for network isolation
$ terraform apply -var-file="dev.tfvars"
  # Creates: VPC 10.0.0.0/16 (small, dev environment)

$ terraform apply -var-file="prod.tfvars"
  # Creates: VPC 10.2.0.0/16 (large, production environment)
```

---

## Key Takeaways

✅ **Use defaults** for non-sensitive, unchanging dev resources  
✅ **Use `-var` flags** for CI/CD automation and dynamic values  
✅ **Use environment variables** for secrets, API keys, AWS credentials  
✅ **Use `.tfvars` files** for environment-specific AWS configurations  
✅ **Combine all methods** for enterprise production deployments  
✅ **Remember precedence:** `-var` flags always win!  
✅ **Secure secrets:** Use AWS Secrets Manager, Parameter Store, or CI/CD vaults  
✅ **Version control:** Commit .tfvars files but NOT sensitive data  
✅ **Audit trail:** Log all deployments in CI/CD systems  
✅ **Test thoroughly:** Validate each environment before production  

---

## AWS Best Practices for Terraform Variables

1. **Never hardcode AWS credentials** — Use IAM roles, assume role, or environment variables
2. **Use sensitive = true** — Mark passwords, keys, and tokens as sensitive in variable definitions
3. **Version control .tfvars** — But add secrets to .gitignore
4. **Use AWS Secrets Manager** — For managing RDS passwords and API keys
5. **Use AWS Parameter Store** — For configuration values
6. **Use Remote State** — Store terraform.tfstate in S3 with encryption
7. **Use State Locking** — Use DynamoDB to prevent concurrent modifications
8. **Tag everything** — Use variables for consistent tagging across resources
9. **Document variables** — Add descriptions for team members
10. **Test all environments** — Plan before applying to catch errors early

