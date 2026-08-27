# Module 03.9: Output Variables in Terraform

## What Are Output Variables?

Output variables store results from your Terraform configuration and display them after resources are created. They let you capture important information like IDs, IPs, and DNS names for later use or integration with other tools.

Think of outputs as the "answers" Terraform gives you after it builds your infrastructure.

---

## Basic Syntax

```hcl
output "output_name" {
  value       = resource_attribute
  description = "What this output shows"
}
```

**Required:** `value` (what to capture)  
**Optional but recommended:** `description` (explain what it is)

---

## AWS Example 1: EC2 Instance Outputs

**Configuration:**

```hcl
resource "aws_instance" "web_server" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  tags = {
    Name = "my-web-server"
  }
}

output "instance_id" {
  value       = aws_instance.web_server.id
  description = "The ID of the EC2 instance"
}

output "instance_public_ip" {
  value       = aws_instance.web_server.public_ip
  description = "The public IP address of the instance"
}

output "instance_arn" {
  value       = aws_instance.web_server.arn
  description = "The ARN of the EC2 instance"
}
```

**After `terraform apply`, you see:**

```
Outputs:

instance_id = i-0c55b159cbfafe1f0
instance_public_ip = 54.123.45.67
instance_arn = arn:aws:ec2:us-east-1:123456789:instance/i-0c55b159cbfafe1f0
```

---

## AWS Example 2: RDS Database Outputs

**Configuration:**

```hcl
resource "aws_db_instance" "main" {
  identifier     = "my-postgres-db"
  engine         = "postgres"
  instance_class = "db.t2.micro"
  allocated_storage = 20

  username = "admin"
  password = random_password.db_password.result
}

resource "random_password" "db_password" {
  length  = 16
  special = true
}

output "database_endpoint" {
  value       = aws_db_instance.main.endpoint
  description = "The connection endpoint for the database"
}

output "database_name" {
  value       = aws_db_instance.main.name
  description = "The database name"
}

output "database_port" {
  value       = aws_db_instance.main.port
  description = "The database port (default 5432 for PostgreSQL)"
}
```

**After `terraform apply`, you see:**

```
Outputs:

database_endpoint = my-postgres-db.c9akciq32.us-east-1.rds.amazonaws.com:5432
database_name = mydb
database_port = 5432
```

---

## AWS Example 3: S3 Bucket Outputs

**Configuration:**

```hcl
resource "aws_s3_bucket" "app_bucket" {
  bucket = "my-app-bucket-${random_id.bucket_id.hex}"

  tags = {
    Name = "My Application Bucket"
  }
}

resource "random_id" "bucket_id" {
  byte_length = 4
}

output "bucket_name" {
  value       = aws_s3_bucket.app_bucket.id
  description = "The name of the S3 bucket"
}

output "bucket_arn" {
  value       = aws_s3_bucket.app_bucket.arn
  description = "The ARN of the S3 bucket"
}

output "bucket_region" {
  value       = aws_s3_bucket.app_bucket.region
  description = "The AWS region where the bucket is located"
}
```

**After `terraform apply`, you see:**

```
Outputs:

bucket_name = my-app-bucket-a1b2c3d4
bucket_arn = arn:aws:s3:::my-app-bucket-a1b2c3d4
bucket_region = us-east-1
```

---

## AWS Example 4: VPC and Security Group Outputs

**Configuration:**

```hcl
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-security-group"
  }
}

output "vpc_id" {
  value       = aws_vpc.main.id
  description = "The ID of the VPC"
}

output "vpc_cidr" {
  value       = aws_vpc.main.cidr_block
  description = "The CIDR block of the VPC"
}

output "security_group_id" {
  value       = aws_security_group.web.id
  description = "The ID of the security group"
}

output "security_group_name" {
  value       = aws_security_group.web.name
  description = "The name of the security group"
}
```

**After `terraform apply`, you see:**

```
Outputs:

vpc_id = vpc-0123456789abcdef0
vpc_cidr = 10.0.0.0/16
security_group_id = sg-0987654321fedcba0
security_group_name = web-sg
```

---

## AWS Example 5: IAM Role Outputs

**Configuration:**

```hcl
resource "aws_iam_role" "lambda_role" {
  name = "lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

output "role_name" {
  value       = aws_iam_role.lambda_role.name
  description = "The name of the IAM role"
}

output "role_arn" {
  value       = aws_iam_role.lambda_role.arn
  description = "The ARN of the IAM role"
}

output "role_id" {
  value       = aws_iam_role.lambda_role.id
  description = "The ID of the IAM role"
}
```

**After `terraform apply`, you see:**

```
Outputs:

role_name = lambda-execution-role
role_arn = arn:aws:iam::123456789:role/lambda-execution-role
role_id = AIDAQ3XAMPLEID
```

---

## Viewing Outputs After Creation

### View All Outputs

```bash
terraform output
```

Shows all output variables with their values.

---

### View Specific Output

```bash
terraform output instance_public_ip
```

Shows only that output's value:
```
54.123.45.67
```

---

### View Outputs in JSON Format

```bash
terraform output -json
```

Useful for scripting and automation:
```json
{
  "instance_id": {
    "value": "i-0c55b159cbfafe1f0",
    "type": "string"
  },
  "instance_public_ip": {
    "value": "54.123.45.67",
    "type": "string"
  }
}
```

---

## Sensitive Outputs

For sensitive data (passwords, API keys, tokens), mark outputs as sensitive:

```hcl
output "database_password" {
  value       = aws_db_instance.main.password
  description = "Database master password"
  sensitive   = true
}
```

When you run `terraform output`, sensitive values show as `<sensitive>` instead of the actual value.

You can still retrieve it with:
```bash
terraform output database_password
```

---

## Multiple Outputs Example

**Complete configuration with many outputs:**

```hcl
# EC2 Instance
resource "aws_instance" "app" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"

  tags = {
    Name = "app-server"
  }
}

# Data source for latest Amazon Linux AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Multiple outputs
output "server_id" {
  value       = aws_instance.app.id
  description = "EC2 instance ID"
}

output "server_ip" {
  value       = aws_instance.app.public_ip
  description = "Public IP of the server"
}

output "server_availability_zone" {
  value       = aws_instance.app.availability_zone
  description = "Availability zone where server is running"
}

output "server_private_ip" {
  value       = aws_instance.app.private_ip
  description = "Private IP of the server"
}
```

**After `terraform apply`:**

```
Outputs:

server_availability_zone = us-east-1a
server_id = i-0c55b159cbfafe1f0
server_ip = 54.123.45.67
server_private_ip = 10.0.1.42
```

---

## Why Use Output Variables?

✅ **Quick Reference** — Get resource details without logging into AWS Console  
✅ **Integration** — Pass values to other tools (Ansible, scripts, CI/CD)  
✅ **Documentation** — Clearly show what resources were created  
✅ **Automation** — Use with `-json` for scripting  
✅ **Team Collaboration** — Share important resource info with teammates  

---

## Best Practices

✅ **Always add descriptions** — Helps others (and future you) understand what each output is  
✅ **Use meaningful names** — `instance_public_ip` is better than `ip`  
✅ **Mark sensitive data** — Use `sensitive = true` for passwords and API keys  
✅ **Group related outputs** — Put all instance outputs together  
✅ **Output important identifiers** — IDs, ARNs, endpoints, IPs  

---

## Key Takeaways

| Concept | Meaning |
|---------|---------|
| **Output** | A way to capture and display resource attributes |
| **Value** | The resource attribute you want to capture (required) |
| **Description** | Explanation of what the output shows (recommended) |
| **Sensitive** | Mark as true for passwords/secrets (optional) |
| **terraform output** | Command to view outputs after creation |

---

## Official Resources

- [Terraform Output Documentation](https://developer.hashicorp.com/terraform/language/values/outputs)
- [AWS Provider Examples](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform CLI Output Command](https://developer.hashicorp.com/terraform/cli/commands/output)

---

## Summary

Output variables are essential for managing Terraform infrastructure. They let you capture resource details immediately after creation, making it easy to reference IDs, IPs, ARNs, and other important information without manually checking the AWS Console. Use them for every resource you create — they cost nothing and provide huge value!
