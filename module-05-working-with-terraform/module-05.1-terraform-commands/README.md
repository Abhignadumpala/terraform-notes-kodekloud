# 📘 Module 5: Terraform Commands

> Essential commands for validating, managing, and visualizing Terraform infrastructure

In this guide, we explore essential Terraform commands used to validate configurations, format files, inspect state, manage providers, output variables, refresh state, and visualize resource dependencies. Each section provides clear examples and outputs to help you master the use of Terraform in your infrastructure management tasks.

---

## **1️⃣ terraform validate**

### **What it does?**

After crafting your Terraform configuration files, you can verify their syntax without running a full plan or apply. The `terraform validate` command checks your configuration for errors, ensuring that your HCL (HashiCorp Configuration Language) is correct.

```
🔍 Checks:
├─ Syntax errors
├─ Unsupported arguments
├─ Invalid resource types
├─ Configuration structure
├─ Required arguments
└─ Resource block validity
```

### **Why Use It?**

```
Benefits:
✅ Early error detection (before plan/apply)
✅ Validates HCL syntax
✅ Checks provider compatibility
✅ Ensures configuration is correct
✅ Useful in CI/CD pipelines
✅ No AWS credentials needed
```

### **Example with AWS**

```hcl
# main.tf - VALID
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  
  tags = {
    Name = "web-server"
  }
}
```

**Run validation:**

```bash
$ terraform validate
Success! The configuration is valid.
```

### **Invalid Example**

```hcl
# main.tf - INVALID (typo: instance_types instead of instance_type)
resource "aws_instance" "web" {
  ami            = "ami-0c55b159cbfafe1f0"
  instance_types = "t2.micro"  # ❌ Wrong argument name
}
```

**Error output:**

```bash
$ terraform validate
Error: Unsupported argument

  on main.tf line 3, in resource "aws_instance" "web":
   3:   instance_types = "t2.micro"

An argument named "instance_types" is not expected here. 
Did you mean "instance_type"?
```

### **When to Use**

```
✅ After writing/editing configuration
✅ Before running plan
✅ In CI/CD pipelines
✅ Quick syntax check
```

---

## **2️⃣ terraform fmt**

### **What it does?**

The `terraform fmt` command scans your configuration files in the current directory and reformats them into a standard style. This canonical formatting greatly improves code readability and consistency. Running the command will list any files that were modified during the formatting process.

```
Fixes:
├─ Indentation (2 spaces standard)
├─ Spacing around equals signs
├─ Bracket alignment
├─ Line breaks
├─ Argument ordering
└─ Consistent style across files
```

### **Why Use It?**

```
Benefits:
✅ Consistent code style across team
✅ Improves readability
✅ Enforces Terraform standards
✅ Catches formatting issues
✅ Automated code cleanup
✅ Required in production workflows
```

### **Example**

**Before (Messy):**

```hcl
# main.tf
resource "aws_instance" "web" {
  ami="ami-0c55b159cbfafe1f0"
  instance_type  =  "t2.micro"
tags={Name="web-server"}
}
```

**Run fmt:**

```bash
$ terraform fmt
main.tf
```

**After (Clean):**

```hcl
# main.tf
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  tags = {
    Name = "web-server"
  }
}
```

### **Common Options**

```bash
# Format current directory
terraform fmt

# Format recursively (all subdirs)
terraform fmt -recursive

# Check what would change (dry-run)
terraform fmt -check

# Format specific file
terraform fmt main.tf
```

### **When to Use**

```
✅ Before committing to Git
✅ Team collaboration (consistent style)
✅ Code reviews
✅ Maintenance
```

---

## **3️⃣ terraform show**

### **What it does?**

The `terraform show` command is used to display the current Terraform state, detailing all attributes of your managed resources. This output helps you verify the actual state of your infrastructure. It provides a human-readable format of everything Terraform knows about your resources.

```
Shows:
├─ Resource types & names
├─ All attributes & values
├─ Resource IDs from AWS
├─ Current configuration values
├─ Sensitive data (marked)
└─ Complete resource details
```

### **Why Use It?**

```
Benefits:
✅ Inspect current infrastructure state
✅ Verify resource details
✅ Get resource IDs/IP addresses
✅ Validate resource configurations
✅ JSON output for automation
✅ Debugging & troubleshooting
```

### **Example with AWS**

**After running terraform apply:**

```bash
$ terraform show

# aws_instance.web:
resource "aws_instance" "web" {
  ami                  = "ami-0c55b159cbfafe1f0"
  arn                  = "arn:aws:ec2:us-east-1:123456789:instance/i-0123456789abcdef0"
  availability_zone    = "us-east-1a"
  instance_state       = "running"
  instance_type        = "t2.micro"
  key_name             = "my-key"
  primary_network_interface_id = "eni-0123456789abcdef0"
  private_dns          = "ip-172-31-1-100.ec2.internal"
  private_ip           = "172.31.1.100"
  public_dns           = "ec2-54-71-34-19.us-east-1.compute.amazonaws.com"
  public_ip            = "54.71.34.19"
  security_groups      = ["sg-0123456789abcdef0"]
  subnet_id            = "subnet-0123456789abcdef0"
  tenancy              = "default"
  vpc_security_group_ids = ["sg-0123456789abcdef0"]

  tags = {
    Name = "web-server"
  }
}
```

### **JSON Format**

```bash
# View in JSON
$ terraform show -json

# Output (formatted):
{
  "format_version": "1.2",
  "terraform_version": "1.5.0",
  "values": {
    "root_module": {
      "resources": [
        {
          "address": "aws_instance.web",
          "mode": "managed",
          "type": "aws_instance",
          "name": "web",
          "provider_name": "registry.terraform.io/hashicorp/aws",
          "instances": [
            {
              "attributes": {
                "ami": "ami-0c55b159cbfafe1f0",
                "instance_type": "t2.micro",
                "public_ip": "54.71.34.19"
              }
            }
          ]
        }
      ]
    }
  }
}
```

### **When to Use**

```
✅ Verify current infrastructure state
✅ Get resource details/IPs
✅ Debugging issues
✅ Collecting resource information
✅ Automation scripts (JSON format)
```

---

## **4️⃣ terraform providers**

### **What it does?**

The `terraform providers` command lists all providers required by your configuration along with those used in your state. It also supports mirroring provider plugins to a specified directory. This helps you understand dependencies and manage provider versions.

```
Shows:
├─ Providers required by configuration
├─ Providers used in state
├─ Provider versions
├─ Provider sources (registry)
└─ Available operations (mirror)
```

### **Why Use It?**

```
Benefits:
✅ View provider dependencies
✅ Verify required versions
✅ Mirror for offline use
✅ Manage provider plugins
✅ Troubleshoot provider issues
✅ Restricted network deployments
```

### **Example**

**Configuration:**

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
}

resource "aws_security_group" "web" {
  name = "web-sg"
}
```

**Check providers:**

```bash
$ terraform providers

Providers required by configuration:
    └── provider[registry.terraform.io/hashicorp/aws] (>= 5.0.0)

Providers required by state:
    └── provider[registry.terraform.io/hashicorp/aws]
```

### **Mirror Providers Locally**

Useful for offline/restricted environments:

```bash
# Mirror to local directory
$ terraform providers mirror /root/terraform/provider-cache

- Mirroring hashicorp/aws...
- Selected v5.10.0
- Downloading package for linux_amd64...
- Package authenticated: signed by HashiCorp
```

### **When to Use**

```
✅ Check which providers you need
✅ Offline environments (mirroring)
✅ Air-gapped networks
✅ Managing provider dependencies
```

---

## **5️⃣ terraform output**

### **What it does?**

Terraform output variables allow you to extract and display configuration values once your infrastructure has been applied. This is particularly useful for showing key results or passing values between modules. Outputs make important information easily accessible for users and automation.

```
Outputs:
├─ Resource IPs/URLs
├─ Resource IDs
├─ Configuration values
├─ Sensitive data (marked/hidden)
├─ Cross-module references
└─ Automation inputs
```

### **Why Use It?**

```
Benefits:
✅ Extract critical information (IPs, IDs)
✅ Pass values to other tools
✅ Documentation of deployed resources
✅ Automation scripts
✅ Module communication
✅ Security (mark sensitive outputs)
```

### **Example with AWS**

**Configuration:**

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  
  tags = {
    Name = "web-server"
  }
}

resource "aws_security_group" "web" {
  name = "web-sg"
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Define outputs
output "instance_id" {
  value       = aws_instance.web.id
  description = "EC2 Instance ID"
}

output "instance_public_ip" {
  value       = aws_instance.web.public_ip
  description = "Public IP of EC2 instance"
}

output "security_group_id" {
  value       = aws_security_group.web.id
  description = "Security Group ID"
}

output "instance_public_dns" {
  value       = aws_instance.web.public_dns
  description = "Public DNS of EC2 instance"
}
```

**View outputs:**

```bash
$ terraform output

instance_id = "i-0123456789abcdef0"
instance_public_ip = "54.71.34.19"
security_group_id = "sg-0987654321fedcba0"
instance_public_dns = "ec2-54-71-34-19.us-east-1.compute.amazonaws.com"
```

**Get specific output:**

```bash
$ terraform output instance_public_ip
54.71.34.19

$ terraform output security_group_id
sg-0987654321fedcba0
```

**JSON format:**

```bash
$ terraform output -json

{
  "instance_id": {
    "value": "i-0123456789abcdef0",
    "type": "string"
  },
  "instance_public_ip": {
    "value": "54.71.34.19",
    "type": "string"
  }
}
```

### **Sensitive Outputs**

```hcl
output "db_password" {
  value       = aws_db_instance.db.password
  sensitive   = true
  description = "Database password (hidden)"
}
```

**Output shows:**

```bash
$ terraform output

db_password = <sensitive>
```

### **When to Use**

```
✅ Get IP addresses for SSH
✅ Extract resource IDs
✅ Pass values to other tools
✅ Documentation
✅ Automation scripts
```

---

## **6️⃣ terraform refresh**

### **What it does?**

The `terraform refresh` command synchronizes your Terraform state with the actual state of your infrastructure. This is particularly useful when external changes have occurred outside of Terraform. It queries AWS for current values and updates the local state file without modifying any resources.

```
Actions:
├─ Queries AWS for current state
├─ Updates state file with real values
├─ Detects infrastructure drift
├─ Does NOT modify infrastructure
├─ Does NOT destroy resources
└─ Safe read-only operation
```

### **Why Use It?**

```
Benefits:
✅ Sync state with manual AWS changes
✅ Detect infrastructure drift
✅ Before creating plan
✅ After others make changes
✅ Regular maintenance
✅ Safe (no modifications made)
```

### **Example Scenario**

**Initial configuration:**

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
}
```

**Someone manually changes instance type in AWS Console to t2.small**

**Refresh state:**

```bash
$ terraform refresh

aws_instance.web: Refreshing state... [id=i-0123456789abcdef0]
```

**Updated state now shows t2.small**

### **Refresh During Plan**

Terraform automatically refreshes during plan:

```bash
$ terraform plan

Refreshing Terraform state in-memory prior to plan...
aws_instance.web: Refreshing state... [id=i-0123456789abcdef0]

Plan: 0 to add, 1 to modify, 0 to destroy.

Resource actions are indicated with the following symbols:
  ~ modify

Terraform will perform the following actions:

  ~ aws_instance "web" {
      ~ instance_type = "t2.small" -> "t2.micro"
        # (other attributes)
    }

Plan: 0 to add, 1 to modify, 0 to destroy.
```

### **Refresh Without Changes**

Update state without modifying infrastructure:

```bash
$ terraform apply -refresh-only

aws_instance.web: Refreshing state... [id=i-0123456789abcdef0]

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

### **Disable Refresh**

For speed (skip drift detection):

```bash
# Plan without refresh
$ terraform plan -refresh=false

# Apply without refresh
$ terraform apply -refresh=false
```

### **When to Use**

```
✅ After manual AWS changes
✅ Before planning
✅ Detecting drift
✅ Syncing after others' changes
✅ Regular maintenance
```

---

## **7️⃣ terraform graph**

### **What it does?**

The `terraform graph` command creates a DOT format representation of resource dependencies in your configuration. The graph visually outlines how resources are connected and their relationships. This helps understand creation order and resource dependencies.

```
Graph shows:
├─ Resource relationships
├─ Provider dependencies
├─ Data source references
├─ Resource ordering/sequencing
├─ Implicit & explicit dependencies
└─ Complete dependency tree
```

### **Why Use It?**

```
Benefits:
✅ Understand resource dependencies
✅ Review creation order
✅ Troubleshoot ordering issues
✅ Team documentation
✅ Complex infrastructure visualization
✅ Dependency analysis
```

### **Example with AWS**

**Configuration with dependency:**

```hcl
# Security Group
resource "aws_security_group" "web" {
  name = "web-sg"
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance (depends on security group)
resource "aws_instance" "web" {
  ami                    = "ami-0c55b159cbfafe1f0"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web.id]  # ← Dependency!
}

# RDS Database
resource "aws_db_instance" "main" {
  allocated_storage = 20
  engine            = "mysql"
  instance_class    = "db.t2.micro"
  name              = "mydb"
  username          = "admin"
  password          = "password123"
  skip_final_snapshot = true
}
```

**Generate graph:**

```bash
$ terraform graph

digraph {
  compound = "true"
  newrank = "true"
  subgraph "root" {
    "[root] aws_security_group.web" [label = "aws_security_group.web", shape = "box"]
    "[root] aws_instance.web" [label = "aws_instance.web", shape = "box"]
    "[root] aws_db_instance.main" [label = "aws_db_instance.main", shape = "box"]
    "[root] provider[\"registry.terraform.io/hashicorp/aws\"]" [label = "provider[\"registry.terraform.io/hashicorp/aws\"]", shape = "diamond"]
    
    "[root] aws_instance.web" -> "[root] aws_security_group.web"
    "[root] aws_instance.web" -> "[root] provider[\"registry.terraform.io/hashicorp/aws\"]"
    "[root] aws_security_group.web" -> "[root] provider[\"registry.terraform.io/hashicorp/aws\"]"
    "[root] aws_db_instance.main" -> "[root] provider[\"registry.terraform.io/hashicorp/aws\"]"
  }
}
```

### **Visualize with Graphviz**

**Install Graphviz:**

```bash
# Ubuntu/Debian
$ apt update && apt install graphviz -y

# macOS
$ brew install graphviz

# Windows
# Download from: https://graphviz.org/download/
```

**Generate visual diagram:**

```bash
# Create SVG
$ terraform graph | dot -Tsvg > graph.svg

# Create PNG
$ terraform graph | dot -Tpng > graph.png

# Create PDF
$ terraform graph | dot -Tpdf > graph.pdf
```

**Open in browser:**

```bash
$ firefox graph.svg
# Or
$ open graph.svg
```

### **What the Graph Shows**

```
Boxes (Resources):
  ┌─────────────────────┐
  │ aws_security_group  │
  └─────────────────────┘

Diamonds (Providers):
  ◇─────────────────────◇
  │ provider[aws]       │
  ◇─────────────────────◇

Arrows (Dependencies):
  aws_instance.web ──→ aws_security_group.web
  (Instance depends on Security Group)
```

### **When to Use**

```
✅ Understand resource relationships
✅ Review dependency order
✅ Troubleshoot creation order
✅ Team documentation
✅ Complex infrastructure visualization
```

---

## **Command Summary Table**

| Command | Purpose | Output | Use Case |
|---------|---------|--------|----------|
| **validate** | Check syntax | Success/Error | Syntax check |
| **fmt** | Format code | Modified files | Code quality |
| **show** | Display state | Resource details | Verify resources |
| **providers** | List providers | Provider info | Dependency mgmt |
| **output** | Show outputs | Output values | Get IPs/IDs |
| **refresh** | Sync state | Updated state | Drift detection |
| **graph** | Show dependencies | DOT format | Visualize |

---

## **Workflow: Using Commands Together**

```
1. Write Configuration
   └─ $ terraform fmt  (format code)

2. Validate
   └─ $ terraform validate  (check syntax)

3. Plan Changes
   └─ $ terraform plan  (auto-refreshes state)

4. Apply Changes
   └─ $ terraform apply

5. Verify Resources
   └─ $ terraform show  (see current state)
   └─ $ terraform output  (get specific values)

6. Understand Dependencies
   └─ $ terraform graph | dot -Tsvg > graph.svg

7. Regular Maintenance
   └─ $ terraform refresh  (sync state)
   └─ $ terraform plan  (detect drift)
```

---

## **Best Practices**

```
✅ Always run terraform fmt before committing

✅ Run terraform validate in CI/CD pipelines

✅ Use terraform show to verify infrastructure

✅ Extract outputs for critical values (IPs, IDs)

✅ Check providers before applying

✅ Refresh state regularly (before plan)

✅ Visualize graph for complex infrastructure

✅ Use JSON output for automation

✅ Never skip validate step in production
```

---

## **Quick Reference**

```bash
# Format code
terraform fmt -recursive

# Validate syntax
terraform validate

# Check current state
terraform show
terraform show -json

# List providers
terraform providers

# Get output values
terraform output
terraform output <output_name>

# Sync state with AWS
terraform refresh
terraform apply -refresh-only

# Visualize dependencies
terraform graph | dot -Tsvg > graph.svg
```

---

**Master these commands for efficient Terraform management!** 🚀

