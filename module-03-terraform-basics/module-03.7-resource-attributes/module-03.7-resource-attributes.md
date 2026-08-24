# Resource Attributes in Terraform - AWS Examples

> Learn to link resources in Terraform using attributes, enhancing infrastructure interdependence and dynamic configurations.

---

## What are Resource Attributes?

### Understanding Resource Attributes

Resource attributes are the properties/outputs that Terraform returns **after** creating a resource. You can reference these attributes from one resource in another resource to create dynamic connections between them.

Think of it like this: When you create something in AWS (an EC2 instance, a security group, a database), AWS returns information about what was created. That information is the **attributes**. Terraform captures these attributes and makes them available for you to use in other resources.

### Why Do Resources Return Attributes?

Every AWS resource creates something tangible in the cloud. When it's created, AWS responds with details about it:

- **EC2 Instance** → Returns: instance ID, public IP, private IP, security groups
- **Security Group** → Returns: security group ID, VPC ID it belongs to
- **RDS Database** → Returns: database endpoint, port, username
- **S3 Bucket** → Returns: bucket name, ARN, region
- **VPC** → Returns: VPC ID, CIDR block, availability zones
- **Subnet** → Returns: subnet ID, CIDR block, VPC it belongs to

All of these returned values are **attributes** that other resources can use and reference.

### The Basic Syntax

```hcl
${resource_type.resource_name.attribute}
```

**Example:**
```hcl
${aws_security_group.web.id}
${aws_db_instance.database.endpoint}
${aws_instance.server.public_ip}
```

---

### In This Lesson: Linking AWS Resources Together

In this lesson, you'll learn how to link two resources together using resource attributes in Terraform. Building on previous concepts of variable reuse, we now extend the idea by connecting two resources, making your AWS infrastructure more dynamic and interdependent.

Terraform configurations often contain multiple resources, each defined with its specific arguments. For example, consider a configuration that includes an EC2 instance resource and a security group resource. For the security group, we specify ingress rules, egress rules, and VPC settings. The EC2 instance, on the other hand, requires parameters like AMI ID, instance type, subnet ID, and security group IDs.

When you run `terraform apply`, Terraform creates both resources, and the security group returns an `id` attribute (e.g., "sg-0123456789abcdef"). This ID is crucial for connecting it to your EC2 instance.

**In real-world AWS infrastructure scenarios, resources frequently depend on each other.** Consider a scenario where:
- You create a VPC and need its ID for your subnet
- You create a subnet and need its ID for your EC2 instance  
- You create a security group and need its ID for your EC2 instance
- You create an RDS database and need its endpoint for your EC2 instance to connect
- You create an S3 bucket and need its ARN for your Lambda function permissions

**The Challenge:** You want to use the output of one resource as an input for another. For example, you want the EC2 instance to automatically reference the security group ID that was just created, rather than hardcoding a value like "sg-12345678" that might become stale or incorrect.

This is where **resource attributes** become powerful. Instead of hardcoding values, you link resources together using their attributes. When resource A is created and returns an attribute, you immediately reference it in resource B. This creates a dynamic, self-aware infrastructure where resources know about each other and automatically adapt to changes.

---

## Example 1: Link Security Group to EC2 Instance

### The Problem
You create a security group and an EC2 instance separately, but want them connected.

### Without Linking (Hardcoded)
```hcl
resource "aws_security_group" "allow_ssh" {
  name = "allow-ssh"
}

resource "aws_instance" "web_server" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  vpc_security_group_ids = ["sg-12345678"]  # Hardcoded - BAD!
}
```

**Problem:** If security group ID changes, you need to manually update the instance config.

### With Linking (Dynamic)
```hcl
resource "aws_security_group" "allow_ssh" {
  name = "allow-ssh"
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web_server" {
  ami                    = "ami-0c55b159cbfafe1f0"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]  # Links to security group!
}
```

**Benefit:** 
- ✅ Security group ID is dynamically referenced
- ✅ If security group changes, instance automatically knows
- ✅ No hardcoding needed

---

## Example 2: Link Database to EC2 Instance

### Scenario
EC2 instance needs to connect to RDS database. Pass database endpoint to EC2 via user data.

```hcl
# Create RDS Database
resource "aws_db_instance" "mysql_db" {
  allocated_storage    = 20
  engine              = "mysql"
  engine_version      = "5.7"
  instance_class      = "db.t2.micro"
  name                = "myapp_db"
  username            = "admin"
  password            = "MyPassword123!"
  publicly_accessible = true
}

# Create EC2 instance and pass database endpoint
resource "aws_instance" "app_server" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  
  user_data = <<-EOF
    #!/bin/bash
    export DB_HOST=${aws_db_instance.mysql_db.endpoint}
    export DB_PORT=3306
    export DB_NAME=${aws_db_instance.mysql_db.name}
    export DB_USER=${aws_db_instance.mysql_db.username}
    # Start application with these env vars
  EOF
}
```

**Key Attributes Referenced:**
- `aws_db_instance.mysql_db.endpoint` → Database connection string
- `aws_db_instance.mysql_db.name` → Database name
- `aws_db_instance.mysql_db.username` → Database user

**Result:** EC2 instance automatically knows database location without hardcoding!

---

## Example 3: Link S3 Bucket to Lambda Function

### Scenario
Lambda function needs to read from S3 bucket. Create bucket, then give Lambda permission and reference bucket name.

```hcl
# Create S3 bucket
resource "aws_s3_bucket" "data_bucket" {
  bucket = "my-app-data-${var.environment}"
}

# Create Lambda execution role
resource "aws_iam_role" "lambda_role" {
  name = "lambda-execution-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Allow Lambda to read from S3 bucket
resource "aws_iam_role_policy" "lambda_s3_policy" {
  name = "lambda-s3-read-policy"
  role = aws_iam_role.lambda_role.id  # Link to IAM role!
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:ListBucket"
      ]
      Resource = [
        aws_s3_bucket.data_bucket.arn,           # Link to S3 bucket!
        "${aws_s3_bucket.data_bucket.arn}/*"
      ]
    }]
  })
}

# Create Lambda function
resource "aws_lambda_function" "processor" {
  filename      = "lambda_function.zip"
  function_name = "data-processor"
  role          = aws_iam_role.lambda_role.arn  # Link to IAM role!
  handler       = "index.handler"
  runtime       = "python3.9"
  
  environment {
    variables = {
      S3_BUCKET_NAME = aws_s3_bucket.data_bucket.id  # Link to S3 bucket!
      S3_BUCKET_ARN  = aws_s3_bucket.data_bucket.arn
    }
  }
}
```

**Attributes Referenced:**
- `aws_iam_role.lambda_role.id` → Role ID for permissions
- `aws_iam_role.lambda_role.arn` → Role ARN for Lambda execution
- `aws_s3_bucket.data_bucket.arn` → Bucket ARN for policy
- `aws_s3_bucket.data_bucket.id` → Bucket name for environment variable

**Benefits:**
- ✅ All resources automatically connected
- ✅ Permissions correctly set without hardcoding ARNs
- ✅ Lambda knows which bucket to access

---

## Example 4: Link VPC to Subnet to Instance

### Scenario
Create VPC → Create Subnet in VPC → Create Instance in Subnet

```hcl
# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Create Subnet in VPC
resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main.id              # Link to VPC!
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

# Create Internet Gateway for VPC
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id                         # Link to VPC!
}

# Create EC2 instance in Subnet
resource "aws_instance" "web" {
  ami                    = "ami-0c55b159cbfafe1f0"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.main.id       # Link to Subnet!
  associate_public_ip_address = true
}
```

**Chain of Dependencies:**
```
VPC (vpc_id)
  ↓
Subnet (vpc_id = aws_vpc.main.id)
  ↓
EC2 Instance (subnet_id = aws_subnet.main.id)
```

**Attributes Referenced:**
- `aws_vpc.main.id` → VPC ID
- `aws_subnet.main.id` → Subnet ID

---

## Example 5: Link Load Balancer to EC2 Instances

### Scenario
Create multiple EC2 instances, then link them to a load balancer.

```hcl
# Create EC2 instances
resource "aws_instance" "web" {
  count           = 3
  ami             = "ami-0c55b159cbfafe1f0"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.web.id]    # Link to security group!
}

# Create security group for web servers
resource "aws_security_group" "web" {
  name = "web-sg"
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create target group
resource "aws_lb_target_group" "web" {
  name        = "web-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id                    # Link to VPC!
}

# Register instances with target group
resource "aws_lb_target_group_attachment" "web" {
  count            = 3
  target_group_arn = aws_lb_target_group.web.arn   # Link to target group!
  target_id        = aws_instance.web[count.index].id  # Link to EC2 instances!
  port             = 80
}

# Create load balancer
resource "aws_lb" "web" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id] # Link to ALB security group!
  subnets            = [aws_subnet.main[0].id, aws_subnet.main[1].id]
}

# Connect load balancer to target group
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn               # Link to load balancer!
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn # Link to target group!
  }
}
```

**Complex Linking:**
```
Security Group → EC2 Instances
                    ↓
                Target Group Attachments
                    ↓
              Target Group
                    ↓
            Load Balancer Listener
```

---

## Common Resource Attributes

### EC2 Instance Attributes
```hcl
aws_instance.web.id                  # Instance ID
aws_instance.web.public_ip           # Public IP
aws_instance.web.private_ip          # Private IP
aws_instance.web.security_groups     # Attached security groups
aws_instance.web.subnet_id           # Subnet it belongs to
```

### RDS Database Attributes
```hcl
aws_db_instance.db.endpoint          # Connection string
aws_db_instance.db.id                # Database identifier
aws_db_instance.db.arn               # Amazon Resource Name
aws_db_instance.db.address           # Database address
aws_db_instance.db.port              # Database port
```

### S3 Bucket Attributes
```hcl
aws_s3_bucket.bucket.id              # Bucket name
aws_s3_bucket.bucket.arn             # Bucket ARN
aws_s3_bucket.bucket.region          # AWS Region
```

### Security Group Attributes
```hcl
aws_security_group.sg.id             # Security group ID
aws_security_group.sg.name           # Security group name
aws_security_group.sg.vpc_id         # VPC it belongs to
```

### VPC Attributes
```hcl
aws_vpc.vpc.id                       # VPC ID
aws_vpc.vpc.cidr_block               # CIDR block
aws_vpc.vpc.arn                       # VPC ARN
```

---

## Interpolation Syntax

### Basic Interpolation
```hcl
"${resource_type.resource_name.attribute}"
```

### In Strings
```hcl
content = "My database is at ${aws_db_instance.db.endpoint}"
```

### Multiple Interpolations
```hcl
endpoint = "${aws_db_instance.db.address}:${aws_db_instance.db.port}"
```

### In Maps/Objects
```hcl
environment {
  variables = {
    DB_HOST = aws_db_instance.db.endpoint
    DB_PORT = aws_db_instance.db.port
  }
}
```

---

## Key Benefits of Linking Resources

✅ **Dynamic:** Changes in one resource automatically update dependent resources  
✅ **No Hardcoding:** Avoid typos and manual updates  
✅ **Dependency Management:** Terraform understands order (creates VPC before subnet)  
✅ **Error Prevention:** If resource name changes, Terraform fails early  
✅ **Scalability:** Works with `count` and `for_each` loops  
✅ **Infrastructure as Code:** Clear relationships between resources  

---

## Complete Real-World Example

```hcl
# Variables
variable "environment" {
  default = "dev"
}

variable "app_port" {
  default = 8080
}

# VPC
resource "aws_vpc" "app" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "app-vpc-${var.environment}"
  }
}

# Subnet
resource "aws_subnet" "app" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

# Security Group for EC2
resource "aws_security_group" "app" {
  vpc_id = aws_vpc.app.id
  name   = "app-sg-${var.environment}"
  
  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
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

# RDS Database
resource "aws_db_instance" "app_db" {
  allocated_storage    = 20
  engine              = "mysql"
  engine_version      = "5.7"
  instance_class      = "db.t2.micro"
  name                = "appdb"
  username            = "admin"
  password            = "TempPassword123!"
  publicly_accessible = false
  
  vpc_security_group_ids = [aws_security_group.db.id]
  db_subnet_group_name   = aws_db_subnet_group.app.name
}

# EC2 Instance
resource "aws_instance" "app_server" {
  ami                    = "ami-0c55b159cbfafe1f0"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.app.id
  vpc_security_group_ids = [aws_security_group.app.id]
  
  user_data = <<-EOF
    #!/bin/bash
    export APP_PORT=${var.app_port}
    export DB_HOST=${aws_db_instance.app_db.endpoint}
    export DB_NAME=${aws_db_instance.app_db.name}
    export DB_USER=${aws_db_instance.app_db.username}
    # Start application
  EOF
  
  tags = {
    Name = "app-server-${var.environment}"
  }
}

# Outputs
output "app_server_private_ip" {
  value = aws_instance.app_server.private_ip
}

output "database_endpoint" {
  value = aws_db_instance.app_db.endpoint
}

output "vpc_id" {
  value = aws_vpc.app.id
}
```

---

## Summary

Resource attributes allow you to:
1. **Reference** one resource in another
2. **Link** resources dynamically
3. **Create** dependencies automatically
4. **Avoid** hardcoding values
5. **Ensure** consistency across infrastructure

This is the foundation of Infrastructure as Code! 🚀
