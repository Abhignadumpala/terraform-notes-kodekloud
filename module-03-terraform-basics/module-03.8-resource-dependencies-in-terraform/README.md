# 3.8: Resource Dependencies in Terraform

> This lesson explores resource dependencies in Terraform, focusing on implicit and explicit dependencies for resource creation and deletion management in AWS infrastructure.

---

## What are Resource Dependencies?

In this lesson, we explore various types of resource dependencies in Terraform and how they affect resource creation and deletion. Terraform uses both implicit and explicit dependencies to manage the order in which resources are provisioned.

Terraform automatically detects **implicit dependencies** through reference expressions. For example, when you pass the output of one resource (like an AWS Security Group) to another resource (such as an EC2 Instance), Terraform understands that the Security Group must be created before the EC2 Instance. 

Similarly, during deletion, Terraform removes the resources in reverse order to maintain consistency.

---

## Table of Contents
1. [Implicit Dependencies](#implicit-dependencies)
2. [Explicit Dependencies](#explicit-dependencies)
3. [Real-World AWS Examples](#real-world-aws-examples)
4. [Dependency Management Best Practices](#dependency-management-best-practices)

---

## Implicit Dependencies

### What are Implicit Dependencies?

Implicit dependencies occur when Terraform automatically detects that one resource depends on another through **reference expressions**. Terraform reads your configuration and understands the order without you explicitly declaring it.

### How Implicit Dependencies Work with AWS

When you reference one AWS resource's output in another AWS resource, Terraform creates an implicit dependency automatically.

### Example 1: EC2 Instance Depends on Security Group

Consider this configuration where an EC2 instance needs a security group:

**File: `main.tf`**
```hcl
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Security group for web server"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-security-group"
  }
}

resource "aws_instance" "web_server" {
  ami                    = "ami-0c55b159cbfafe1f0"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web.id]  # ← IMPLICIT DEPENDENCY

  tags = {
    Name = "web-server"
  }
}
```

**What Happens:**

Terraform automatically detects that `aws_instance.web_server` references `aws_security_group.web.id`. This creates an **implicit dependency**.

**Creation Order:**
1. ✅ Security Group (`aws_security_group.web`) is created FIRST
2. ✅ EC2 Instance (`aws_instance.web_server`) is created SECOND

**Deletion Order:**
1. ✅ EC2 Instance is destroyed FIRST
2. ✅ Security Group is destroyed SECOND

**Why?** Because the EC2 instance needs the security group to exist and be assigned to it. Terraform ensures the security group is available before creating the instance.

---

### Example 2: RDS Database Depends on DB Parameter Group

```hcl
resource "aws_db_parameter_group" "postgres" {
  name   = "postgres-params"
  family = "postgres13"

  parameter {
    name  = "max_connections"
    value = "100"
  }

  parameter {
    name  = "shared_buffers"
    value = "256000"
  }

  tags = {
    Name = "postgres-parameter-group"
  }
}

resource "aws_db_instance" "production" {
  identifier              = "prod-postgres-db"
  engine                  = "postgres"
  engine_version          = "13.7"
  instance_class          = "db.t2.micro"
  allocated_storage       = 20
  db_name                 = "production"
  username                = "admin"
  password                = var.db_master_password
  parameter_group_name    = aws_db_parameter_group.postgres.name  # ← IMPLICIT DEPENDENCY
  skip_final_snapshot     = false

  tags = {
    Name = "production-database"
  }
}
```

**What Happens:**

The RDS instance references `aws_db_parameter_group.postgres.name`, creating an implicit dependency.

**Creation Order:**
1. ✅ Parameter Group is created FIRST
2. ✅ RDS Database is created SECOND (with the parameter group applied)

**Deletion Order:**
1. ✅ RDS Database is destroyed FIRST
2. ✅ Parameter Group is destroyed SECOND

**Why?** The parameter group configuration must exist and be ready before the database is created, otherwise the database won't have the proper configuration applied.

---

### Example 3: Lambda Function Depends on IAM Role

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

  tags = {
    Name = "lambda-role"
  }
}

resource "aws_lambda_function" "my_function" {
  filename      = "function.zip"
  function_name = "my-lambda-function"
  role          = aws_iam_role.lambda_role.arn  # ← IMPLICIT DEPENDENCY
  handler       = "index.handler"
  runtime       = "python3.9"

  tags = {
    Name = "my-function"
  }
}
```

**What Happens:**

The Lambda function references `aws_iam_role.lambda_role.arn`, creating an implicit dependency.

**Creation Order:**
1. ✅ IAM Role is created FIRST
2. ✅ Lambda Function is created SECOND (assigned to the role)

**Deletion Order:**
1. ✅ Lambda Function is destroyed FIRST
2. ✅ IAM Role is destroyed SECOND

**Why?** Lambda needs an IAM role to exist before it can be created. Without the role, Lambda has no identity and cannot be assigned permissions.

---

## Explicit Dependencies

### What are Explicit Dependencies?

Explicit dependencies are when you **manually declare** that a resource depends on another using the `depends_on` argument. Use this when there's an **indirect dependency** that Terraform can't automatically detect through references.

### Basic Concept with AWS

Sometimes a resource might indirectly rely on another resource without any direct reference. In these cases, you explicitly specify the dependency using the `depends_on` argument. This method ensures that Terraform provisions and destroys resources in the intended order.

---

### Example 1: Lambda Depends on IAM Policy Attachment

**Problem:** Lambda needs the IAM policy to be attached BEFORE it's created, but Lambda doesn't directly reference the policy.

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

resource "aws_iam_role_policy" "lambda_logs" {
  name   = "lambda-logs-policy"
  role   = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_lambda_function" "my_function" {
  filename      = "function.zip"
  function_name = "my-lambda-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "python3.9"

  depends_on = [
    aws_iam_role_policy.lambda_logs  # ← EXPLICIT DEPENDENCY
  ]

  tags = {
    Name = "my-function"
  }
}
```

**What Happens:**

Even though Lambda doesn't directly reference the policy, you explicitly declare that it depends on it using `depends_on`.

**Creation Order:**
1. ✅ IAM Role is created FIRST
2. ✅ IAM Policy is attached to the role SECOND
3. ✅ Lambda Function is created THIRD (only after policy is attached)

**Deletion Order:**
1. ✅ Lambda Function is destroyed FIRST
2. ✅ IAM Policy is detached SECOND
3. ✅ IAM Role is destroyed THIRD

**Why?** Without the policy, Lambda would be created without proper permissions to write logs. By using `depends_on`, you ensure the policy is fully attached before Lambda creation attempts, preventing a race condition.

---

### Example 2: RDS Database Depends on DB Subnet Group

**Problem:** RDS database needs the subnet group to be fully created before it can be created, but the relationship isn't clear through a simple reference.

```hcl
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_db_subnet_group" "main" {
  name       = "main-db-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "main-db-subnet-group"
  }
}

resource "aws_db_instance" "production" {
  identifier              = "prod-db"
  engine                  = "postgres"
  engine_version          = "13.7"
  instance_class          = "db.t2.micro"
  allocated_storage       = 20
  db_subnet_group_name    = aws_db_subnet_group.main.name
  username                = "admin"
  password                = var.db_master_password
  skip_final_snapshot     = false

  depends_on = [
    aws_db_subnet_group.main  # ← EXPLICIT DEPENDENCY
  ]

  tags = {
    Name = "production-database"
  }
}
```

**What Happens:**

You explicitly declare that the RDS database depends on the DB subnet group being fully created.

**Creation Order:**
1. ✅ Subnets are created FIRST
2. ✅ DB Subnet Group is created SECOND (combining the subnets)
3. ✅ RDS Database is created THIRD (only after subnet group is ready)

**Deletion Order:**
1. ✅ RDS Database is destroyed FIRST
2. ✅ DB Subnet Group is destroyed SECOND
3. ✅ Subnets are destroyed THIRD

**Why?** The subnet group must be fully initialized with all subnets added before the RDS database attempts to use it. Without explicit dependency, there could be a race condition.

---

### Example 3: S3 Notification to Lambda

**Problem:** S3 bucket needs to trigger Lambda, but this requires S3 to have permission to invoke Lambda, which must be created first.

```hcl
resource "aws_s3_bucket" "data" {
  bucket = "my-data-bucket-${data.aws_caller_identity.current.account_id}"
}

resource "aws_lambda_function" "processor" {
  filename      = "processor.zip"
  function_name = "data-processor"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "python3.9"
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.data.arn
}

resource "aws_s3_bucket_notification" "data_notification" {
  bucket = aws_s3_bucket.data.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [
    aws_lambda_permission.allow_s3  # ← EXPLICIT DEPENDENCY
  ]
}
```

**What Happens:**

The S3 notification explicitly depends on the Lambda permission being created first.

**Creation Order:**
1. ✅ S3 Bucket is created FIRST
2. ✅ Lambda Function is created SECOND
3. ✅ Lambda Permission (to invoke from S3) is created THIRD
4. ✅ S3 Notification is created FOURTH (only after Lambda has permission)

**Deletion Order:**
1. ✅ S3 Notification is destroyed FIRST
2. ✅ Lambda Permission is revoked SECOND
3. ✅ Lambda Function is destroyed THIRD
4. ✅ S3 Bucket is destroyed FOURTH

**Why?** S3 cannot trigger Lambda without explicit permission. By using `depends_on`, you ensure the permission exists before S3 tries to set up the notification trigger.

---

## Real-World AWS Examples

### Scenario 1: Multi-Environment Deployment

When deploying the same infrastructure to development, staging, and production, dependencies ensure resources are created consistently:

**Development (Small Instance):**
```hcl
resource "aws_security_group" "dev_web" {
  name        = "dev-web-sg"
  description = "Development web server security group"
  # ... ingress/egress rules ...
}

resource "aws_instance" "dev_web" {
  ami                    = "ami-0c55b159cbfafe1f0"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.dev_web.id]
}
```

**Production (Multi-AZ with Load Balancer):**
```hcl
resource "aws_security_group" "prod_web" {
  name = "prod-web-sg"
  # ... rules ...
}

resource "aws_db_subnet_group" "prod_db" {
  name       = "prod-db-subnet-group"
  subnet_ids = [aws_subnet.prod_1.id, aws_subnet.prod_2.id]
}

resource "aws_instance" "prod_web" {
  count                  = 2
  ami                    = "ami-0c55b159cbfafe1f0"
  instance_type          = "t2.medium"
  vpc_security_group_ids = [aws_security_group.prod_web.id]
}

resource "aws_db_instance" "prod_db" {
  identifier           = "prod-db"
  engine              = "postgres"
  engine_version      = "13.7"
  instance_class      = "db.t3.small"
  allocated_storage   = 100
  db_subnet_group_name = aws_db_subnet_group.prod_db.name
  multi_az            = true

  depends_on = [
    aws_db_subnet_group.prod_db
  ]
}
```

**Why Dependencies Matter:** Development and production have different security requirements and scaling needs. Dependencies ensure that regardless of environment size, resources are created in the correct order.

---

### Scenario 2: Database with Backup Configuration

```hcl
resource "aws_rds_cluster" "main" {
  cluster_identifier      = "my-database-cluster"
  engine                  = "aurora-postgresql"
  database_name           = "mydb"
  master_username         = "admin"
  master_password         = var.db_password
  backup_retention_period = 30

  depends_on = [
    aws_db_subnet_group.main
  ]
}

resource "aws_s3_bucket" "db_backups" {
  bucket = "db-backups-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "db_backups" {
  bucket = aws_s3_bucket.db_backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_db_cluster_snapshot" "backup" {
  db_cluster_identifier      = aws_rds_cluster.main.id
  db_cluster_snapshot_identifier = "backup-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  depends_on = [
    aws_s3_bucket_versioning.db_backups
  ]
}
```

**Why Dependencies Matter:** The database must be fully created and running before you can create a snapshot of it. The S3 bucket versioning must be enabled before backup snapshots are stored.

---

## Comparison: Implicit vs Explicit Dependencies

| Aspect | Implicit Dependencies | Explicit Dependencies |
|--------|----------------------|----------------------|
| **Declaration** | Through references (outputs) | Using `depends_on` argument |
| **Detection** | Automatic by Terraform | Manual by developer |
| **Readability** | Clear from code | Needs comments |
| **Use Case** | Direct resource references | Hidden/indirect dependencies |
| **Example** | `aws_security_group.web.id` | `depends_on = [aws_iam_role_policy]` |
| **Automation** | Automatic | Requires manual maintenance |
| **When to Use** | Most scenarios | Policy attachments, permissions |

---

## Dependency Management Best Practices

### ✅ DO:

1. **Let Terraform Handle Implicit Dependencies**
   ```hcl
   # ✅ GOOD: Terraform detects dependency automatically
   vpc_security_group_ids = [aws_security_group.web.id]
   ```

2. **Use `depends_on` for Policy Attachments**
   ```hcl
   # ✅ GOOD: Explicit dependency for IAM policies
   depends_on = [
     aws_iam_role_policy.lambda_logs
   ]
   ```

3. **Document Why `depends_on` Is Needed**
   ```hcl
   # ✅ GOOD: Clear comment explaining the dependency
   depends_on = [
     aws_iam_role_policy.lambda  # Policy must be attached before Lambda creation
   ]
   ```

4. **Test Destruction Order**
   ```bash
   # ✅ GOOD: Verify correct destruction order
   terraform plan -destroy
   ```

### ❌ DON'T:

1. **Don't Use `depends_on` When References Work**
   ```hcl
   # ❌ BAD: Redundant and unclear
   depends_on = [aws_security_group.web]
   vpc_security_group_ids = [aws_security_group.web.id]
   ```

2. **Don't Create Circular Dependencies**
   ```hcl
   # ❌ BAD: A depends on B, B depends on A
   resource "aws_lambda_function" "a" {
     depends_on = [aws_lambda_function.b]
   }
   
   resource "aws_lambda_function" "b" {
     depends_on = [aws_lambda_function.a]
   }
   ```

3. **Don't Forget `depends_on` for IAM Policies**
   ```hcl
   # ❌ BAD: Race condition - Lambda created before policy attached
   resource "aws_lambda_function" "my_func" {
     role = aws_iam_role.lambda.arn
   }
   ```

---

---

## Ways to Call Attributes in Another Resource

### Two Different Syntaxes

When referencing resources in Terraform, there are two main ways to pass attribute values. Understanding when to use each is crucial for writing correct configuration.

#### 1. Direct Reference (Preferred in Lists/Values)

Use direct references when passing values to resource attributes:

```hcl
vpc_security_group_ids = [aws_security_group.web.id]
```

**Use Cases:**
- Assigning to lists or arrays
- Passing single attribute values
- Conditions and logic
- JSON objects and data structures

---

#### 2. String Interpolation (For String Concatenation)

Use string interpolation when building strings or embedding values inside text:

```hcl
content = "My security group ID is ${aws_security_group.web.id}"
```

**Use Cases:**
- Concatenating values with text
- Building file content
- Creating descriptive strings
- User data scripts

---

### The Rule of Thumb

🎯 **Simple Rule:**

- **Direct Reference** (`aws_security_group.web.id`) → For attributes and values
- **Interpolation** (`"${aws_security_group.web.id}"`) → When inside a string

---

### Summary: When to Use Which

| Context | Use | Example |
|---------|-----|---------|
| **Passing to resource attribute** | Direct Reference | `vpc_security_group_ids = [aws_security_group.web.id]` |
| **Inside a string** | String Interpolation | `"ID: ${aws_security_group.web.id}"` |
| **In tags (string value)** | Either (but Direct is cleaner) | `Name = aws_security_group.web.id` or `Name = "${aws_security_group.web.id}"` |

**Best Practice:** Use direct reference when possible. Use interpolation only when building strings. 🎯

---

### Real-World Examples from AWS

**Direct Reference Examples:**
```hcl
# ✅ CORRECT: EC2 using security group
vpc_security_group_ids = [aws_security_group.web.id]

# ✅ CORRECT: Lambda using IAM role
role = aws_iam_role.lambda.arn

# ✅ CORRECT: RDS using parameter group
parameter_group_name = aws_db_parameter_group.postgres.name

# ✅ CORRECT: Multiple resources in a list
subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]
```

**String Interpolation Examples:**
```hcl
# ✅ CORRECT: File content with embedded ID
content = "Security Group: ${aws_security_group.web.id}"

# ✅ CORRECT: User data script
user_data = "echo 'SG ID: ${aws_security_group.web.id}' > /tmp/sg.txt"

# ✅ CORRECT: Lambda environment variable
environment {
  variables = {
    SG_MESSAGE = "Using security group: ${aws_security_group.web.id}"
  }
}

# ✅ CORRECT: Tags with description
tags = {
  Description = "Database created with SG ${aws_security_group.web.id}"
}
```

---

## Key Takeaways

✅ **Implicit dependencies** — Terraform automatically detects through references  
✅ **Explicit dependencies** — Use `depends_on` for hidden relationships  
✅ **IAM policies need `depends_on`** — Always specify explicit dependency  
✅ **Deletion is reverse order** — Terraform destroys in opposite creation order  
✅ **Test your dependencies** — Run `terraform plan` before applying  
✅ **Document complex dependencies** — Add comments explaining `depends_on`  
✅ **Avoid circular dependencies** — They cause deployment failures  
✅ **Use direct references** — For passing values to attributes  
✅ **Use interpolation** — Only when building strings with embedded values  

---

## Common AWS Dependency Patterns

| Resource | Depends On | Method |
|----------|-----------|--------|
| EC2 Instance | Security Group | Implicit (reference) |
| Lambda Function | IAM Role | Implicit (reference) |
| Lambda Function | IAM Policy | Explicit (`depends_on`) |
| RDS Database | DB Subnet Group | Implicit/Explicit |
| ALB Listener | Target Group | Implicit (reference) |
| S3 Notification | Lambda Permission | Explicit (`depends_on`) |
| EIP | Internet Gateway | Explicit (`depends_on`) |

