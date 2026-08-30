# Module 4.0 Troubleshooting: Security Group Not Attached Gotcha

> Common mistake: Creating a security group but forgetting to attach it to the EC2 instance. The state file reveals this immediately.

---

## The Problem

While building my lab, I created a security group but forgot to reference it in the EC2 instance configuration.

**My Original Code (WRONG):**

```hcl
resource "aws_security_group" "web_sg" {
  name        = "web-security-group"
  description = "Security group for web server"
  
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

# ❌ Missing: vpc_security_group_ids = [...]
resource "aws_instance" "web_server" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type
  
  tags = {
    Name = "my-web-server"
  }
}
```

**What Happened:**

1. ✅ Terraform created the security group: `sg-03ee8ffc10cd43d96`
2. ✅ Terraform created the EC2 instance: `i-077f37d5b08506306`
3. ❌ The instance used AWS's **default security group** instead: `sg-0aed90982121d95d8`
4. ❌ Terraform didn't warn me — it's valid to have unused resources

---

## How I Caught It

I checked the state file and noticed the instance was using a different security group ID than the one I created:

```bash
cat terraform.tfstate | jq '.resources[] | select(.type == "aws_security_group") | .instances[0].attributes.id'
# Output: "sg-03ee8ffc10cd43d96" (my web_sg)

cat terraform.tfstate | jq '.resources[] | select(.type == "aws_instance") | .instances[0].attributes.vpc_security_group_ids'
# Output: ["sg-0aed90982121d95d8"] (AWS default SG!)
```

**The mismatch revealed the bug immediately.** 🔍

---

## The Fix

I added the missing line to attach the security group:

**Corrected Code (RIGHT):**

```hcl
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "web_sg" {
  name        = "web-security-group"
  description = "Security group for web server"
  
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

# ✅ FIXED: Added vpc_security_group_ids
resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.web_sg.id]  # ✅ ATTACHED!
  
  tags = {
    Name = "my-web-server"
  }
}
```

---

## Key Lessons

1. **Terraform won't warn you** — An unreferenced resource is still valid syntax. It just sits there unused.

2. **The state file is your debugging tool** — Cross-check resource IDs in state against what you intended to use.

3. **Use terraform state commands:**
   ```bash
   # See what's in state
   terraform state list
   
   # Show details of a specific resource
   terraform state show aws_instance.web_server
   
   # Compare attributes
   terraform state show aws_security_group.web_sg
   ```

4. **Easy to miss** — This happens because Terraform allows partial configurations. AWS then applies defaults (like the default security group), and if you don't inspect the state file, you won't know.

---

## How to Prevent This

✅ Always attach security groups explicitly:
```hcl
vpc_security_group_ids = [aws_security_group.web_sg.id]
```

✅ Inspect state after `apply`:
```bash
terraform state show aws_instance.web_server | grep vpc_security_group_ids
```

✅ Cross-check console against state:
- Look at the EC2 instance in AWS Console
- Verify the security group shown matches your `web_sg` ID
- If it shows "default", you forgot to attach

---

## Summary

**The Gotcha:** Creating resources but not connecting them = silent failure.

**The Solution:** Use Terraform state to verify every resource is configured as intended.

**The Lesson:** State files aren't just for tracking — they're your audit trail for debugging configuration mistakes.

