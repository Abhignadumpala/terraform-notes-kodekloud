# 📘 Module 5.2: Mutable vs Immutable Infrastructure

> Understanding the two approaches to infrastructure management and why Terraform favors immutability

In this lesson, we dive into the fundamental differences between mutable and immutable infrastructure. Understanding these differences is essential when implementing Infrastructure as Code (IaC) and using tools like Terraform. Terraform handles resource updates by destroying an existing resource and then re-creating it with the updated settings, exemplifying immutable infrastructure by default.

---

## **1️⃣ What is Mutable Infrastructure?**

### **Definition**

Mutable infrastructure allows resources to be modified in-place after deployment. The underlying infrastructure persists while its configuration, software, or settings change over time.

```
Mutable = Change existing resources
├─ Modify in-place
├─ Keep same instances/servers
├─ Update without replacement
└─ Infrastructure persists
```

### **Real-World Example: Nginx Upgrade**

Imagine you are running an application server with Nginx version 1.17. When a new version is released, you might choose to update the web server incrementally—from version 1.17 to 1.18, and later from 1.18 to 1.19.

**Process:**
```
Nginx 1.17 (running) 
  ↓ (in-place upgrade)
Nginx 1.18 (running) 
  ↓ (in-place upgrade)
Nginx 1.19 (running)

Same EC2 instance the entire time!
```

### **AWS Example: Mutable Update**

```hcl
# EC2 Instance v1
resource "aws_instance" "web_server" {
  ami           = "ami-0c55b159cbfafe1f0"  # Amazon Linux 2
  instance_type = "t2.micro"
  
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y nginx-1.17
    systemctl start nginx
  EOF
  
  tags = {
    Name = "web-server"
  }
}
```

**Later, you SSH into the instance and manually upgrade Nginx:**

```bash
# On the EC2 instance (manual in-place update)
$ ssh ec2-user@instance-ip
$ sudo yum update -y
$ sudo yum install -y nginx-1.19  # Upgrade in-place
$ sudo systemctl restart nginx

# Instance ID remains the same!
# Only the software changed
```

### **Mutable Updates: Common Methods**

```
Method 1: Manual SSH
├─ SSH into server
├─ Run commands manually
└─ Update software/config

Method 2: Ansible (Config Management)
├─ Run playbook on running instance
├─ Update in-place
└─ Instance keeps running

Method 3: Custom Scripts
├─ Run upgrade scripts
├─ Modify configuration
└─ Service restart
```

---

## **2️⃣ Challenges with Mutable Infrastructure**

### **Configuration Drift**

When updating software on a system, inconsistencies can emerge:

```
Pool of 3 Web Servers (all Nginx 1.17):
  ├─ Server 1: Successfully upgraded to 1.19 ✅
  ├─ Server 2: Successfully upgraded to 1.19 ✅
  └─ Server 3: Upgrade failed - stayed at 1.17 ❌
               (Network issue / Dependency missing)

Result: CONFIGURATION DRIFT
Different software versions running!
```

### **Real AWS Scenario: Configuration Drift**

```
Initial State (all identical):
┌──────────────────────────────┐
│ EC2 Instance 1               │
│ ├─ Nginx: 1.17               │
│ ├─ PHP: 7.4                  │
│ └─ MySQL Client: 5.7         │
└──────────────────────────────┘

┌──────────────────────────────┐
│ EC2 Instance 2               │
│ ├─ Nginx: 1.17               │
│ ├─ PHP: 7.4                  │
│ └─ MySQL Client: 5.7         │
└──────────────────────────────┘

After Manual Updates (DRIFT):
┌──────────────────────────────┐
│ EC2 Instance 1 (UPDATED)     │
│ ├─ Nginx: 1.19  ✅            │
│ ├─ PHP: 8.0     ✅            │
│ └─ MySQL Client: 8.0 ✅       │
└──────────────────────────────┘

┌──────────────────────────────┐
│ EC2 Instance 2 (FAILED)      │
│ ├─ Nginx: 1.17  ❌ (old)      │
│ ├─ PHP: 7.4     ❌ (old)      │
│ └─ MySQL Client: 5.7 ❌ (old) │
└──────────────────────────────┘

Now they're DIFFERENT!
```

### **Problems Caused by Configuration Drift**

```
❌ Inconsistent behavior across servers
   - Same code runs differently on each server
   - Bugs appear on some servers but not others

❌ Difficult troubleshooting
   - Why does Instance 1 work but Instance 2 fails?
   - Hours spent debugging version differences

❌ Failed updates cascade
   - If one server fails to upgrade, it stays old
   - Future upgrades become even more complex

❌ Unpredictable failures
   - One server handles load, another crashes
   - Hard to predict which will fail

❌ Maintenance nightmare
   - Keeping track of which server is at which version
   - Rolling back becomes complicated
```

### **Downtime Risks**

```
Update Process Issues:
├─ Dependencies may fail
├─ Services may crash during update
├─ Rollback is manual and error-prone
└─ Can cause unexpected downtime

Example: Nginx Service Crash During Update
  Before: Nginx 1.17 (running smoothly)
  Update: Install 1.19 with new config format
  Problem: Old config incompatible with 1.19
  Result: Service crashes during update!
```

---

## **3️⃣ What is Immutable Infrastructure?**

### **Definition**

Immutable infrastructure means resources are never modified after deployment. When changes are needed, you create brand-new resources and decommission the old ones.

```
Immutable = Replace existing resources
├─ Never modify in-place
├─ Always create new instances
├─ Delete old ones after testing
└─ Infrastructure constantly renewed
```

### **Real-World Example: Nginx Upgrade (Immutable)**

```
Nginx 1.17 (old server running)
  ↓ (create new server with 1.18)
Nginx 1.18 (new server created & tested)
  ↓ (switch traffic to new server)
Nginx 1.18 (now running, old server deleted)
  ↓ (create new server with 1.19)
Nginx 1.19 (new server created & tested)
  ↓ (switch traffic, delete 1.18 server)
Nginx 1.19 (running)

Different EC2 instances each time!
```

### **AWS Example: Immutable Infrastructure with Terraform**

```hcl
# Create AMI with Nginx 1.17
resource "aws_ami_from_instance" "nginx_1_17" {
  name                    = "nginx-1-17-ami"
  source_instance_id      = aws_instance.web_server.id
  snapshot_without_reboot = true
}

# Launch new instance with Nginx 1.19
resource "aws_launch_template" "web_nginx_1_19" {
  name_prefix = "nginx-1-19-"
  
  image_id = "ami-nginx-1-19"  # New AMI with 1.19
  
  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y nginx-1.19
    systemctl start nginx
  EOF
  )
}

# Auto Scaling Group (replaces old instances)
resource "aws_autoscaling_group" "web" {
  name                = "web-asg"
  availability_zones  = ["us-east-1a", "us-east-1b"]
  min_size            = 2
  max_size            = 4
  desired_capacity    = 3
  
  launch_template {
    id      = aws_launch_template.web_nginx_1_19.id
    version = "$Latest"
  }
  
  # Old instances will be replaced automatically
  lifecycle {
    create_before_destroy = true  # New before old dies
  }
}
```

**What happens:**
```
Step 1: Old instances (Nginx 1.17) running
        ├─ Instance-1
        ├─ Instance-2
        └─ Instance-3

Step 2: New instances (Nginx 1.19) created
        ├─ Instance-1 (Nginx 1.17) - still running
        ├─ Instance-2 (Nginx 1.17) - still running
        ├─ Instance-3 (Nginx 1.17) - still running
        ├─ Instance-4 (Nginx 1.19) - NEW ✅
        ├─ Instance-5 (Nginx 1.19) - NEW ✅
        └─ Instance-6 (Nginx 1.19) - NEW ✅

Step 3: Load balancer switches traffic to new instances
        └─ All traffic now goes to Nginx 1.19

Step 4: Old instances terminated
        ├─ Instance-1 ❌ Deleted
        ├─ Instance-2 ❌ Deleted
        └─ Instance-3 ❌ Deleted
```

---

## **4️⃣ Benefits of Immutable Infrastructure**

### **✅ No Configuration Drift**

```
All instances created fresh from same template
├─ Identical software versions
├─ Same configuration
├─ No "version creep"
└─ Consistent environments

Example: 3 new instances deployed
  ├─ Instance-1: Nginx 1.19, PHP 8.0, MySQL 8.0 ✅
  ├─ Instance-2: Nginx 1.19, PHP 8.0, MySQL 8.0 ✅
  └─ Instance-3: Nginx 1.19, PHP 8.0, MySQL 8.0 ✅
  
  All identical guaranteed!
```

### **✅ Easy Rollback**

```
Version control for infrastructure:
  ├─ v1.0: Nginx 1.17 (Launch Template 1)
  ├─ v1.1: Nginx 1.18 (Launch Template 2)
  ├─ v1.2: Nginx 1.19 (Launch Template 3) ← Current
  └─ Rollback to v1.1: Just switch to Launch Template 2

Simply:
  1. Change launch template to previous version
  2. New instances spin up
  3. Terminate new problematic instances
  4. Done! Back to known-good state
```

### **✅ Reliable Deployments**

```
Every deployment is a fresh creation
├─ Not dependent on existing state
├─ No surprise dependencies
├─ Predictable behavior
└─ Same process every time

Testing is guaranteed:
  ├─ New instances thoroughly tested
  ├─ Only after success, traffic switched
  ├─ Zero risk of partial updates
  └─ All-or-nothing deployment
```

### **✅ Version Infrastructure**

```
Like code versioning for infrastructure:
  ├─ git tag v1.0-production
  ├─ git tag v1.1-hotfix
  └─ git tag v1.2-feature

Each tag represents a known-good state
with specific:
  ├─ AMI versions
  ├─ Software versions
  ├─ Configuration
  └─ Dependencies
```

---

## **5️⃣ Terraform and Immutable Infrastructure**

### **Terraform's Default Behavior**

Terraform exemplifies immutable infrastructure by default. When you update a resource, Terraform destroys the original and creates a new one. Notice the **"-/+"** symbol which means destroy and recreate (immutable).

### **Important: Terraform Has BOTH Mutable and Immutable Behavior**

Not all changes force replacement! Terraform actually supports BOTH:

**✅ Mutable Attributes (In-Place Update)** — No resource replacement:
```
├─ Tags (Name, Environment, etc.)
├─ Descriptions
├─ Monitoring settings
├─ Some configuration values
└─ Instance ID stays the SAME
```

**❌ Immutable Attributes (Destroy & Recreate)** — Forces replacement:
```
├─ Instance Type (t2.micro → t2.small)
├─ AMI (ami-123 → ami-456)
├─ VPC or Availability Zone
├─ Root volume configuration
└─ Instance ID becomes DIFFERENT
```

### **Example 1: Tag Change (Mutable - In-Place)**

**Initial:**

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  id            = "i-0abc123def456abc"
  
  tags = {
    Name = "web-server-v1"
  }
}
```

**Update: Only change the tag**

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  id            = "i-0abc123def456abc"  # STAYS SAME!
  
  tags = {
    Name = "web-server-v2"  # Changed!
  }
}
```

**Terraform Plan Output (Mutable - No replacement):**

```bash
$ terraform plan

# aws_instance.web will be updated in-place
~ resource "aws_instance" "web" {
    ami           = "ami-0c55b159cbfafe1f0"
    instance_type = "t2.micro"
    id            = "i-0abc123def456abc"  # ✅ SAME ID
  ~ tags = {
      ~ "Name" = "web-server-v1" -> "web-server-v2"
    }
}

Plan: 0 to add, 1 to change, 0 to destroy.  # No destruction!
```

**Apply Output:**

```bash
aws_instance.web: Modifying... [id=i-0abc123def456abc]
aws_instance.web: Modifications complete after 2s

Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

**Result:** Instance continues running - only tag updated in-place! ✅

---

### **Example 2: Instance Type Change (Immutable - Destroy & Recreate)**

**Initial Configuration (t2.micro):**

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"  # Small instance
  
  tags = {
    Name = "web-server"
  }
}
```

**Update: Change instance type to t2.small**

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.small"  # Changed! (larger instance)
  
  tags = {
    Name = "web-server"
  }
}
```

**Terraform Plan Output (Immutable - Destroy & Recreate):**

```bash
$ terraform plan

# aws_instance.web must be replaced
-/+ resource "aws_instance" "web" {
      + ami                  = "ami-0c55b159cbfafe1f0"
      ~ instance_type        = "t2.micro" -> "t2.small"  # forces replacement
      - id                   = "i-0abc123def456abc" -> (known after apply)
      + public_ip            = (known after apply)
      + private_ip           = (known after apply)
      + vpc_security_group_ids = (known after apply)
      tags = {
        Name = "web-server"
      }
}

Plan: 1 to add, 0 to change, 1 to destroy.
```

**Apply Output:**

```bash
$ terraform apply

# aws_instance.web must be replaced
-/+ resource "aws_instance" "web" {
      ~ instance_type = "t2.micro" -> "t2.small"  # forces replacement
}

Do you want to perform these actions?
Terraform will perform the following actions:

  # aws_instance.web must be replaced
  -/+ resource "aws_instance" "web" {
        ~ instance_type = "t2.micro" -> "t2.small"
        # (other attributes)
      }

Plan: 1 to add, 0 to change, 1 to destroy.

aws_instance.web: Destroying... [id=i-0abc123def456abc]
aws_instance.web: Destruction complete after 15s

aws_instance.web: Creating...
aws_instance.web: Creation complete after 8s [id=i-0xyz789def123xyz]

Apply complete! Resources: 1 added, 0 changed, 1 destroyed.
```

**What happened (Immutable):**
```
Old instance: i-0abc123def456abc (t2.micro) ❌ DESTROYED
New instance: i-0xyz789def123xyz (t2.small) ✅ CREATED

Notice:
├─ Instance ID changed completely
├─ Public IP changed (new instance)
├─ Private IP may change
└─ All from scratch - immutable approach!
```

### **Another AWS Example: Security Group Rules**

**Initial Configuration:**

```hcl
resource "aws_security_group" "web" {
  name = "web-sg"
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all
  }
}
```

**Update: Restrict to specific IP**

```hcl
resource "aws_security_group" "web" {
  name = "web-sg"
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["203.0.113.0/24"]  # Specific IP range
  }
}
```

**Terraform Plan Output:**

```bash
$ terraform plan

# aws_security_group.web must be replaced
-/+ resource "aws_security_group" "web" {
      ~ ingress {
            from_port   = 80
            to_port     = 80
            protocol    = "tcp"
          ~ cidr_blocks = ["0.0.0.0/0"] -> ["203.0.113.0/24"]  # forces replacement
        }
      - id      = "sg-0abc123def456" -> (known after apply)
      ~ vpc_id  = "vpc-12345678" (unchanged, but resource replaced)
}

Plan: 1 to add, 0 to change, 1 to destroy.
```

**Key Point:** Even security groups are replaced when their rules change - true immutability!

### **Real AWS Example: EC2 Immutable Update**

```hcl
# EC2 instance with specific AMI
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"  # v1.17
  instance_type = "t2.micro"
  
  tags = {
    Name = "web-server"
  }
}
```

**Update AMI to new version:**

```hcl
resource "aws_instance" "web" {
  ami           = "ami-1234567890abcdef0"  # v1.19 (new AMI)
  instance_type = "t2.micro"
  
  tags = {
    Name = "web-server"
  }
}
```

**Terraform destroys old instance, creates new:**

```bash
$ terraform apply

# aws_instance.web must be replaced
-/+ resource "aws_instance" "web" {
      + ami                  = "ami-1234567890abcdef0"  # NEW AMI
      ~ instance_type        = "t2.micro"
      - id                   = "i-0abc123def456" -> (known after apply)
      - tags                 = { Name = "web-server" } -> (known after apply)
}

Plan: 1 to add, 0 to change, 1 to destroy.

aws_instance.web: Destroying... [id=i-0abc123def456]
aws_instance.web: Destruction complete after 5s
aws_instance.web: Creating...
aws_instance.web: Creation complete after 8s
Apply complete! Resources: 1 added, 0 destroyed, 0 changed, 1 destroyed.
```

---

## **6️⃣ Comparison Table: Mutable vs Immutable**

| Aspect | Mutable | Immutable |
|--------|---------|-----------|
| **Update Method** | Modify in-place | Replace with new |
| **Configuration Drift** | ❌ High risk | ✅ Impossible |
| **Rollback Speed** | ⚠️ Manual, slow | ✅ Switch template |
| **Testing** | ⚠️ Update on prod | ✅ Test then deploy |
| **Downtime Risk** | ❌ Service crashes during update | ✅ No downtime (switching) |
| **Consistency** | ❌ Servers diverge | ✅ All identical |
| **Complexity** | ⚠️ Track versions | ✅ Simple, predictable |
| **Terraform** | Possible (with lifecycle) | Default behavior |
| **Best Practice** | Legacy systems | Modern IaC |

---

## **7️⃣ Handling Immutable Infrastructure Challenges**

### **Challenge: Creating New Before Deleting Old**

By default, Terraform destroys first, then creates (might cause downtime).

**Solution: Use Lifecycle Rules**

```hcl
resource "aws_instance" "web" {
  ami           = "ami-new-version"
  instance_type = "t2.micro"
  
  lifecycle {
    create_before_destroy = true  # Create new FIRST
  }
  
  tags = {
    Name = "web-server"
  }
}
```

**What happens:**
```
1. New instance created ✅
2. Wait for it to pass health checks
3. Switch load balancer traffic
4. Delete old instance ✅

Zero downtime!
```

### **Challenge: Handling Dependent Resources**

Some AWS resources can't be replaced (like databases with data).

**Solution: Use ignore_changes**

```hcl
resource "aws_db_instance" "main" {
  allocated_storage = 20
  engine            = "mysql"
  instance_class    = "db.t2.micro"
  
  lifecycle {
    ignore_changes = [
      allocated_storage  # Keep existing storage
    ]
  }
}
```

This keeps the database while other settings can be immutable.

---

## **8️⃣ Best Practices**

```
✅ Use immutable infrastructure by default
   └─ Create new resources instead of modifying

✅ Version your infrastructure
   └─ Tag AMIs, launch templates with versions

✅ Test in staging first
   └─ Create new resources, validate, then promote

✅ Use Auto Scaling Groups
   └─ Automatically replace old instances with new

✅ Implement health checks
   └─ Only send traffic to healthy new instances

✅ Keep configuration in code
   └─ Never make manual AWS Console changes

✅ Use Terraform lifecycle rules carefully
   └─ Understand create_before_destroy, ignore_changes

✅ Plan for zero-downtime deployments
   └─ Always have new ready before old dies

❌ Avoid SSHing into instances for updates
   └─ Creates configuration drift

❌ Don't mix mutable and immutable
   └─ Pick one approach, stick with it

❌ Never make manual AWS changes
   └─ Goes against IaC principles

❌ Don't ignore configuration drift
   └─ It multiplies complexity over time
```

---

## **9️⃣ AWS Services Supporting Immutable Infrastructure**

```
Auto Scaling Groups
├─ Launch new instances automatically
├─ Replace old with new
└─ Perfect for immutable approach

EC2 Launch Templates
├─ Define instance specifications
├─ Version them
└─ Easily create new instances from template

Application Load Balancer (ALB)
├─ Distribute traffic
├─ Zero-downtime deployments
└─ Switch between old and new instances

CloudFormation / Terraform
├─ Infrastructure as Code
├─ Version control infrastructure
└─ Reproducible deployments

Elastic Beanstalk
├─ Handles deployments
├─ Can do blue-green deployments
└─ Simplified immutable infrastructure
```

---

## **🔟 Summary**

| Concept | Key Points |
|---------|-----------|
| **Mutable** | Modify existing → Configuration drift → Complex rollback |
| **Immutable** | Replace resources → Consistent → Easy rollback |
| **Terraform** | Default immutable → Destroy old, create new |
| **AWS Best Practice** | Use immutable with Auto Scaling + Load Balancers |
| **Benefits** | Reliability, consistency, version control, easy rollback |
| **Challenges** | Downtime during updates (solved with lifecycle rules) |

---

## **Key Takeaways**

```
1️⃣ Mutable = In-place updates (risky)
   ├─ Software stays on same server
   ├─ Configuration drift emerges
   └─ Rollback is manual and dangerous

2️⃣ Immutable = Always replace (safe)
   ├─ New resources, new server
   ├─ No configuration drift
   └─ Rollback is one config change

3️⃣ Terraform is immutable by default
   ├─ Destroys old, creates new
   ├─ Aligns with IaC best practices
   └─ But can be modified with lifecycle rules

4️⃣ Use immutable for production
   ├─ Consistent environments
   ├─ Easier troubleshooting
   ├─ Reliable deployments
   └─ Better security posture

5️⃣ Plan for zero-downtime
   ├─ Use create_before_destroy
   ├─ Test new instances first
   ├─ Switch traffic gradually
   └─ Delete old only after verification
```

---

**Immutable infrastructure is the foundation of modern DevOps!** 🚀

