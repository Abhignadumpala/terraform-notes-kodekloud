# 📘 Module 10.2: Creating and Using a Module

> In this note, I create a reusable Terraform module and use it to deploy the same infrastructure in more than one environment.

---

## Overview

Imagine a company called FlexIT Consulting that has built a prototype payroll software. It needs to be deployed in several countries on AWS, using the same core architecture each time.

The simple architecture uses the default VPC and has these parts:

- An EC2 instance (using a custom AMI) that runs the application server.
- A DynamoDB NoSQL database that stores employee and payroll data.
- An S3 bucket that stores documents like pay stubs and tax forms.
- Users who access the application on the EC2 instance.

Together these parts make a basic deployment of the payroll application: users reach the app on the EC2 instance inside the VPC, and the app reads and writes data in the DynamoDB table and the S3 bucket.

The goal is to wrap this setup in a Terraform module, so the same stack can be deployed in different regions. Based on this design, I write the Terraform configuration.

> 💡 Some values, like the instance type, are hard-coded so every region gets the same setup. Others, like the AMI and the region-based naming, come from variables so I can change them per region.

---

## Module Directory Structure

I create the module in a folder named `modules`, at this path:

```text
/root/terraform-projects/modules/payroll-app
```

In this folder, I create the files for the AWS resources: an EC2 instance, an S3 bucket, and a DynamoDB table.

```bash
$ mkdir -p /root/terraform-projects/modules/payroll-app
# Create the following files inside the payroll-app directory:
#   app_server.tf, dynamodb_table.tf, s3_bucket.tf, variables.tf
```

---

## EC2 Instance Configuration (`app_server.tf`)

```hcl
resource "aws_instance" "app_server" {
  ami           = var.ami
  instance_type = "t3.medium"
  tags = {
    Name = "${var.app_region}-app-server"
  }
  depends_on = [
    aws_dynamodb_table.payroll_db,
    aws_s3_bucket.payroll_data
  ]
}
```

Official docs: [`aws_instance`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance).

---

## S3 Bucket Configuration (`s3_bucket.tf`)

```hcl
resource "aws_s3_bucket" "payroll_data" {
  bucket = "${var.app_region}-${var.bucket}"
}
```

Official docs: [`aws_s3_bucket`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket).

---

## DynamoDB Table Configuration (`dynamodb_table.tf`)

```hcl
resource "aws_dynamodb_table" "payroll_db" {
  name         = "user_data"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "EmployeeID"

  attribute {
    name = "EmployeeID"
    type = "N"
  }
}
```

Official docs: [`aws_dynamodb_table`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table).

---

## Variable Declarations (`variables.tf`)

The module uses these variables so each deployment can be a little different:

```hcl
variable "app_region" {
  type = string
}

variable "bucket" {
  default = "flexit-payroll-alpha-22001c"
}

variable "ami" {
  type = string
}
```

---

## Deploying the Application Stack

### Deployment in the US East 1 Region

To deploy the stack in US East 1, I create a new folder (for example, `/root/terraform-projects/us-payroll-app`) to be the root module, and add this `main.tf` inside it:

```bash
$ mkdir -p /root/terraform-projects/us-payroll-app
```

```hcl
module "us_payroll" {
  source     = "../modules/payroll-app"
  app_region = "us-east-1"
  ami        = "ami-0a1b2c3d4e5f60001" # my custom payroll AMI in us-east-1
}

provider "aws" {
  region = "us-east-1"
}
```

This configuration tells the AWS provider to work in the US East 1 region, using my custom AMI. The module hard-codes values like the instance type and the DynamoDB table settings for consistency, but it still lets me change the bucket name and AMI per region.

I initialize, plan, and apply with these commands:

```bash
$ terraform init
$ terraform plan
$ terraform apply
```

A sample output from `terraform apply`:

```Terraform
Terraform will perform the following actions:
# module.us_payroll.aws_dynamodb_table.payroll_db will be created
+ resource "aws_dynamodb_table" "payroll_db" {
    arn          = (known after apply)
    billing_mode = "PAY_PER_REQUEST"
    hash_key     = "EmployeeID"
    name         = "user_data"
  }
# module.us_payroll.aws_instance.app_server will be created
+ resource "aws_instance" "app_server" {
    ami           = "ami-0a1b2c3d4e5f60001"
    instance_type = "t3.medium"
  }
# module.us_payroll.aws_s3_bucket.payroll_data will be created
+ resource "aws_s3_bucket" "payroll_data" {
    bucket = "us-east-1-flexit-payroll-alpha-22001c"
  }

Enter a value: yes
module.us_payroll.aws_dynamodb_table.payroll_db: Creating...
```

### Deployment in the UK (London) Region

To deploy the same stack in the UK, I create another folder (for example, `/root/terraform-projects/uk-payroll-app`) for the root module. Both `app_region` and the AMI are different in this region, so `main.tf` looks like this:

```bash
$ mkdir -p /root/terraform-projects/uk-payroll-app
```

```hcl
module "uk_payroll" {
  source     = "../modules/payroll-app"
  app_region = "eu-west-2"
  ami        = "ami-0a1b2c3d4e5f60002" # my custom payroll AMI in eu-west-2
}

provider "aws" {
  region = "eu-west-2"
}
```

When I run `terraform apply` in this folder, Terraform deploys the same stack in the London region. The S3 bucket name gets the region code in front of it automatically:

```Terraform
Terraform will perform the following actions:
# module.uk_payroll.aws_dynamodb_table.payroll_db will be created
+ resource "aws_dynamodb_table" "payroll_db" {
    arn          = (known after apply)
    billing_mode = "PAY_PER_REQUEST"
    hash_key     = "EmployeeID"
    name         = "user_data"
  }
# module.uk_payroll.aws_instance.app_server will be created
+ resource "aws_instance" "app_server" {
    ami           = "ami-0a1b2c3d4e5f60002"
    instance_type = "t3.medium"
  }
# module.uk_payroll.aws_s3_bucket.payroll_data will be created
+ resource "aws_s3_bucket" "payroll_data" {
    bucket = "eu-west-2-flexit-payroll-alpha-22001c"
  }

Enter a value: yes
module.uk_payroll.aws_dynamodb_table.payroll_db: Creating...
module.uk_payroll.aws_s3_bucket.payroll_data: Creating...
module.uk_payroll.aws_dynamodb_table.payroll_db: Creation complete after 1s [id=user_data]
```

> 💡 I make sure I have the right AWS credentials set up for each target region before running Terraform commands.

---

## Module Resource Addressing

When I use modules, each resource's address joins the module name, the resource type, and the resource name. For example, the DynamoDB table in the `us_payroll` module is:

```Terraform
module.us_payroll.aws_dynamodb_table.payroll_db
```

This addressing keeps module resources organized and makes it easier to manage configurations when deploying the same stack in many regions.

Official docs: [Resource addressing](https://developer.hashicorp.com/terraform/cli/state/resource-addressing).

---

## Summary

In this note, I built a Terraform module to deploy a payroll application across multiple AWS regions. By putting the resource definitions into a reusable module, I keep important settings the same everywhere — like the instance type, the DynamoDB table name, and the primary key — while still allowing regional changes like the AMI and the S3 bucket name.

- ✅ Modules make infrastructure easier to manage, cut repeated configuration, and lower the risk of misconfigured resources
- ✅ Each root module (`us-payroll-app`, `uk-payroll-app`) calls the same module with its own values and its own `provider` region
- ✅ Module resources are addressed as `module.<module_name>.<resource_type>.<resource_name>`

---

## Key Takeaway

**I write the stack once as a module, then each region is just a small root module that calls it with different values.**

- ✅ Fixing or improving the module updates every region the next time it's applied
- ⚠️ `terraform init` must run in each root module folder before `plan` and `apply`

---

## Practice & Next Steps

Build `modules/payroll-app` and the `us-payroll-app` root module, run `terraform init` and `terraform plan`, and check that every resource in the plan starts with `module.us_payroll.`. Then add `uk-payroll-app` and compare the bucket names in the two plans.

Learn more:

- [Terraform Modules](https://developer.hashicorp.com/terraform/language/modules)
- [AWS Provider for Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

Next up: 10.3 — using modules from the Public Terraform Registry.
