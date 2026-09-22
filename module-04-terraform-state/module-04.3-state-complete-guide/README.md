# 📘 Module 4: Terraform State

> Terraform State is the single source of truth for your infrastructure

---

## **1️⃣ What is State File?**

```
🔍 Definition
├─ File that keeps track of real infrastructure
├─ Maps configuration (HCL) to actual AWS resources
├─ Stored in JSON format
└─ By default: terraform.tfstate (local)
```

### **Why State is Important?**

| Need | Without State | With State |
|------|---------------|-----------|
| Track Resources | ❌ No memory | ✅ Knows all IDs |
| Prevent Duplicates | ❌ Creates again | ✅ Skips existing |
| Detect Changes | ❌ No baseline | ✅ Compares to plan |
| Dependencies | ❌ Unknown | ✅ Tracks order |
| Team Work | ❌ Local copies | ✅ Central source |

### **State File Content (JSON)**

```json
{
  "version": 4,
  "serial": 1,
  "resources": [
    {
      "type": "aws_instance",
      "name": "web",
      "id": "i-0123456789abcdef0",
      "attributes": {
        "ami": "ami-12345678",
        "instance_type": "t2.micro",
        "public_ip": "54.71.34.19"
      }
    }
  ]
}
```

---

## **2️⃣ Terraform State Workflow**

```
┌──────────────────────────────────────────────┐
│                                              │
│  1. Write Configuration (main.tf)            │
│     └─ Define what you want                 │
│                                              │
│  2. terraform plan                           │
│     └─ Read state + compare to config       │
│     └─ Show what will change                │
│                                              │
│  3. terraform apply                          │
│     └─ Create/modify/delete in AWS          │
│     └─ Update terraform.tfstate              │
│                                              │
│  4. State File Updated                       │
│     ├─ terraform.tfstate (new)               │
│     └─ terraform.tfstate.backup (old)        │
│                                              │
│  5. Next Plan/Apply                          │
│     └─ Always refers to latest state         │
│                                              │
└──────────────────────────────────────────────┘
```

---

## **3️⃣ State Commands**

| Command | Purpose | Example | Use Case |
|---------|---------|---------|----------|
| **list** | See all resources in state | `terraform state list` | Quick inventory |
| **show** | Details of one resource | `terraform state show aws_instance.web` | Debugging |
| **pull** | Download current state | `terraform state pull > backup.json` | Backup |
| **push** | Upload state file | `terraform state push state.json` | Recovery |
| **rm** | Remove from state | `terraform state rm aws_instance.web` | Stop managing |
| **import** | Add existing resource | `terraform import aws_instance.web i-123` | Adopt resource |
| **mv** | Rename/move resource | `terraform state mv aws_instance.web aws_instance.api` | Refactor |

### **Quick Tips:**
- 💡 List what Terraform manages → `terraform state list`
- 💡 Debug a specific resource → `terraform state show <resource>`
- 💡 Safe backup → `terraform state pull > backup.json`

---

## **4️⃣ State Locking**

```
🔒 What is Locking?

Prevents multiple users from modifying state 
at the same time (concurrent modifications)

Without Locking:           With Locking:
User A: terraform apply    User A: terraform apply (lock acquired)
User B: terraform apply    User B: terraform apply (waits for lock)
        ❌ Conflict!              ✅ Waits automatically
```

### **Locking Mechanism (Native S3 — Terraform 1.10+)**

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket       = "my-state"
    key          = "prod/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true  # ← Enables locking, no DynamoDB table needed
    encrypt      = true
  }
}
```

> ⚠️ **Correction:** this section used to show `dynamodb_table` as the way to enable locking. As of Terraform 1.10+, that's deprecated — `use_lockfile = true` does the same job directly through S3, with no separate DynamoDB table to create, pay for, or keep in sync. `dynamodb_table` still works for older Terraform versions or existing setups mid-migration. Full setup, IAM permissions, and a real hands-on migration from `dynamodb_table` to `use_lockfile` are in **[Module 4.2](../module-04.2-terraform-state-considerations/README.md#setting-up-s3-as-a-remote-backend)**.

### **How it Works:**

```
User A wants to plan:
├─ terraform plan
├─ Acquires the lock (a lock file in S3, or a DynamoDB record on older setups)
├─ Gets latest state
├─ Shows plan
└─ Releases lock

During this time:
User B tries to plan:
├─ terraform plan
├─ Tries to acquire lock
├─ ⏳ WAITS (lock is held)
└─ Gets lock when User A releases
```

---

## **5️⃣ State Backup & Versioning**

### **Automatic Backup**

```
Before terraform apply:
  terraform.tfstate (serial: 2)

After terraform apply:
  terraform.tfstate (serial: 3)  ← New
  terraform.tfstate.backup (serial: 2)  ← Old
```

### **Backup Strategies**

| Strategy | How | Best For |
|----------|-----|----------|
| **S3 Versioning** | Enable versioning on S3 bucket | Production |
| **Cross-Region** | Replicate state to another region | Disaster recovery |
| **Manual Backup** | `terraform state pull > backup.json` | Before major changes |
| **Automated** | CI/CD pipeline backs up state | Team environments |

### **Example: S3 Versioning**

```hcl
resource "aws_s3_bucket_versioning" "state" {
  bucket = "my-terraform-state"
  
  versioning_configuration {
    status = "Enabled"  # ← Keeps all versions
  }
}
```

---

## **6️⃣ State Drift**

Drift = state/config no longer match the real infrastructure, because something changed the real resource outside Terraform.

```
Example:
  State says: EC2 t2.micro
  Reality: Someone manually changed it to t2.small

Result: Terraform doesn't know the instance was modified,
until the next `terraform plan` refreshes state and catches it.
```

This section used to stop at "re-run `terraform apply` to fix it" — that's only half the picture, since sometimes the external change was *correct* and I want to keep it, not undo it. See **[Module 4.4: State Drift](../module-04.4-state-drift/README.md)** for the full breakdown: how `plan` actually detects drift, reverting it vs. deliberately adopting it with `-refresh-only`, and prevention practices.

---

## **7️⃣ Backends**

> 📌 Full standalone treatment now in **[Module 7: Remote State](../../module-07-remote-state/)** — S3 backend setup/security/locking in [7.1](../../module-07-remote-state/module-07.1-s3-remote-backend-and-locking/README.md), plus a new topic not covered here: sharing state across separate stacks with `terraform_remote_state`, in [7.2](../../module-07-remote-state/module-07.2-cross-stack-state-sharing/README.md).

### **What is Backend?**

```
Backend = WHERE Terraform stores the state file

Local (Default)          Remote (Production)
└─ terraform.tfstate     ├─ S3 (native locking, Terraform 1.10+)
   └─ In current dir     ├─ Terraform Cloud
                         ├─ Azure Storage
                         └─ GCS
```

### **Local Backend (Default)**

```
How it works:
Terraform CLI
  └─ Read/Write
     └─ terraform.tfstate (local disk)

Pros:
  ✅ Simple, no setup
  ✅ Good for learning

Cons:
  ❌ Not for teams
  ❌ No locking
  ❌ Risk of state file corruption
  ❌ Hard to backup
```

### **Remote Backend (S3, Native Locking)**

```
How it works:
Terraform CLI
  └─ Read/Write
     └─ S3 Bucket ← State file
        ├─ Encrypted at rest
        ├─ Versioning enabled
        ├─ Access controlled via IAM
        └─ Lock file also stored here (use_lockfile = true)
           — no separate DynamoDB table needed, Terraform 1.10+

Pros:
  ✅ Team collaboration
  ✅ Automatic locking
  ✅ Encryption & versioning
  ✅ Audit trail
  ✅ One less piece of infrastructure to run/pay for than the old DynamoDB setup

Cons:
  ⚠️ Slightly more setup than local
```

### **Backend Configuration**

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket       = "my-terraform-state"
    key          = "prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

(On Terraform versions before 1.10, use `dynamodb_table = "terraform-locks"` instead — see [Module 4.2](../module-04.2-terraform-state-considerations/README.md) for the full migration path from one to the other.)

---

## **8️⃣ Sensitive Data in State**

### **⚠️ CRITICAL: State Contains Secrets**

```
State File Holds:
  ❌ RDS master passwords (plaintext!)
  ❌ IAM access keys (live & usable!)
  ❌ API keys and tokens
  ❌ Private IPs and network details
  ❌ SSH key references
```

### **Real Example:**

```json
{
  "type": "aws_db_instance",
  "attributes": {
    "master_username": "admin",
    "master_password": "MySecretPassword123!"  ← PLAINTEXT!
  }
}
```

### **Security Best Practices:**

```
🔒 Never:
  ❌ Commit terraform.tfstate to Git
  ❌ Email state files
  ❌ Store unencrypted locally

✅ Always:
  ✅ Store remotely (S3 + encryption)
  ✅ Enable S3 versioning
  ✅ Restrict IAM access
  ✅ Use state locking
  ✅ Enable audit logging
  ✅ Add to .gitignore
```

### **.gitignore for State**

```bash
# Never commit state files
terraform.tfstate
terraform.tfstate.*
terraform.tfstate.backup
.terraform/
```

---

## **9️⃣ Import Existing Resources**

### **Use Case:**

```
You have running EC2 instances in AWS
But Terraform doesn't know about them
Goal: Bring them under Terraform management
```

### **How Import Works:**

```
Step 1: Add resource definition (skeleton)
  resource "aws_instance" "web" {
    # Configuration here
  }

Step 2: Import the real resource
  terraform import aws_instance.web i-0123456789abcdef0

Step 3: Terraform reads the instance details
  └─ Gets ID, AMI, instance type, etc.
  └─ Writes to state file

Step 4: Complete the configuration
  resource "aws_instance" "web" {
    ami           = "ami-12345678"  ← From import
    instance_type = "t2.micro"      ← From import
  }

Step 5: Verify
  terraform plan  # Should show no changes
```

---

## **🔟 Refresh State**

### **What is Refresh?**

```
Refresh = Update state file to match current AWS

Without refresh:
  State is old/stale
  Doesn't know if resources still exist

With refresh:
  Queries AWS, updates state file, now matches reality
```

### **When to Refresh:**

```
✅ After manual AWS changes
✅ Before creating a plan
✅ If you suspect drift
✅ After someone else made changes
```

### **Command:**

```bash
# terraform plan already refreshes automatically — no separate step needed
terraform plan
```

> ⚠️ **Correction:** this section used to list `terraform refresh` as the manual command for this. That command is **deprecated** — confirmed against the current Terraform CLI docs. Use `terraform plan -refresh-only` or `terraform apply -refresh-only` instead, which let me review the refreshed values before they're written to state (the old `terraform refresh` applied them immediately, with no review step). Full detail in **[Module 4.4: State Drift](../module-04.4-state-drift/README.md)**.

---

## **Summary Table**

| Concept | What is it? | When to Use |
|---------|-----------|-----------|
| **State File** | Infrastructure memory | Always needed |
| **Local State** | File on your computer | Learning only |
| **Remote State** | S3 (native locking, Terraform 1.10+) | Production/teams |
| **Locking** | Prevents conflicts | Multi-user teams |
| **Backup** | Copy of state | Disaster recovery |
| **Drift** | Actual vs. desired | Detecting changes |
| **Import** | Adopt existing resources | Legacy infrastructure |
| **Refresh** | Sync with AWS | Detecting drift |

---

## **🎯 Key Takeaways**

```
1️⃣ State = Single Source of Truth
   └─ Terraform knows what it created

2️⃣ Never Commit to Git
   └─ Contains plaintext passwords

3️⃣ Use Remote Backend in Production
   └─ S3 + native locking (use_lockfile) + Encryption

4️⃣ Enable Locking for Teams
   └─ Prevents concurrent modifications

5️⃣ Backup Regularly
   └─ Versioning + Manual backups

6️⃣ Detect Drift
   └─ Run terraform plan regularly

7️⃣ Use IAM to Protect State
   └─ Restrict access to S3 bucket

8️⃣ Keep State Synchronized
   └─ Refresh after manual changes
```

---

## **Best Practices Checklist**

```
Local Development:
  ☐ Store locally (terraform.tfstate)
  ☐ Add to .gitignore
  ☐ Backup before major changes

Team/Production:
  ☐ Use remote backend (S3)
  ☐ Enable encryption at rest
  ☐ Enable versioning
  ☐ Enable locking (use_lockfile on Terraform 1.10+, or DynamoDB on older versions)
  ☐ Restrict IAM access
  ☐ Enable audit logging (CloudTrail)
  ☐ Never commit to Git
  ☐ Backup state regularly

Operations:
  ☐ Run terraform plan before apply
  ☐ Check for drift regularly
  ☐ Document state structure
  ☐ Limit who can modify state
  ☐ Use workspaces for environments
```

---

**Remember: Your state file is as important as your database! Protect it accordingly.** 🔐

