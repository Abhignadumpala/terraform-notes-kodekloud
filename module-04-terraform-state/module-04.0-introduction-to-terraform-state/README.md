# Module 04.0: Introduction to Terraform State

> In this class we will learn Terraform state and state management, understanding how it tracks infrastructure changes and the significance of the state file in managing AWS resources.

---

## What is Terraform State?

Terraform state is a record of all the infrastructure Terraform has created. It maps your real-world AWS resources to the resource definitions in your Terraform configuration files. Without state, Terraform wouldn't know which resources exist or how to update them.

---

## Terraform Workflow Overview

Imagine you have a project directory named "terraform-aws-project" containing the following files:

```bash
$ ls terraform-aws-project
main.tf  variables.tf  provider.tf
```

The primary Terraform configuration is defined in `main.tf`:

```hcl
resource "aws_instance" "web_server" {
  ami           = var.ami_id
  instance_type = var.instance_type

  tags = {
    Name = "my-web-server"
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
```

The variables are declared in `variables.tf`:

```hcl
variable "ami_id" {
  default = "ami-0c55b159cbfafe1f0"
}

variable "instance_type" {
  default = "t2.micro"
}
```

The AWS provider is configured in `provider.tf`:

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
  region = "us-east-1"
}
```

At this stage, no AWS resources have been created yet.

---

## Initializing and Running Terraform Plan

Before provisioning any resources, initialize Terraform by executing the `terraform init` command. This downloads the necessary AWS provider plugin. Next, generate an execution plan with the `terraform plan` command. Notice that Terraform refreshes the state in memory (even if no state exists yet) and computes an execution plan showing which resources will be created.

The output of the plan command looks similar to this:

```bash
$ terraform plan
Refreshing Terraform state in-memory prior to plan...
The refreshed state will be used to calculate this plan, persisted to local or remote state storage.

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_security_group.web_sg will be created
  + resource "aws_security_group" "web_sg" {
      + arn                    = (known after apply)
      + description            = "Security group for web server"
      + egress                 = [
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + from_port        = 0
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "-1"
              + security_groups  = []
              + to_port          = 0
            },
        ]
      + id                     = (known after apply)
      + ingress                = [
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + from_port        = 80
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = []
              + to_port          = 80
            },
        ]
      + name                   = "web-security-group"
      + owner_id               = (known after apply)
      + tags                   = {
          + "Name" = "web-security-group"
        }
      + vpc_id                 = (known after apply)
    }

  # aws_instance.web_server will be created
  + resource "aws_instance" "web_server" {
      + ami                    = "ami-0c55b159cbfafe1f0"
      + availability_zone      = (known after apply)
      + cpu_core_count         = (known after apply)
      + id                     = (known after apply)
      + instance_state         = (known after apply)
      + instance_type          = "t2.micro"
      + primary_network_interface_id = (known after apply)
      + private_ip             = (known after apply)
      + public_ip              = (known after apply)
      + tags                   = {
          + "Name" = "my-web-server"
        }
    }

Plan: 2 to add, 0 to change, 0 to destroy.

Note: You didn't specify an -out parameter to save this plan, so it will not be possible to replay this exact plan thereafter.
```

Since the state file does not yet exist, Terraform understands that all resources defined in the configuration will be newly created.

---

## Applying the Terraform Configuration

To apply the configuration, run the `terraform apply` command. This reinitializes the in-memory state, confirms that no state file exists yet, and then proceeds to create the AWS resources:

```bash
$ terraform apply
An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_security_group.web_sg will be created
  + resource "aws_security_group" "web_sg" {
      + arn         = (known after apply)
      + description = "Security group for web server"
      + id          = (known after apply)
      + name        = "web-security-group"
      + owner_id    = (known after apply)
      + vpc_id      = (known after apply)
    }

  # aws_instance.web_server will be created
  + resource "aws_instance" "web_server" {
      + ami                    = "ami-0c55b159cbfafe1f0"
      + id                     = (known after apply)
      + instance_type          = "t2.micro"
      + private_ip             = (known after apply)
      + public_ip              = (known after apply)
    }

Plan: 2 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

Enter a value: yes

aws_security_group.web_sg: Creating...
aws_security_group.web_sg: Creation complete after 1s [id=sg-0987654321fedcba0]
aws_instance.web_server: Creating...
aws_instance.web_server: Creation complete after 30s [id=i-0c55b159cbfafe1f0]

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

Upon confirmation, Terraform creates both resources, generates unique IDs for them, and stores these details in the state file. If you run `terraform apply` again, Terraform refreshes the state, detects that the resources already exist, and confirms that no further actions are needed:

```bash
$ terraform apply
aws_security_group.web_sg: Refreshing state... [id=sg-0987654321fedcba0]
aws_instance.web_server: Refreshing state... [id=i-0c55b159cbfafe1f0]

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

Terraform maintains a state file to track that these resources are already provisioned.

---

## The Terraform State File

After the initial successful `terraform apply`, an additional file named `terraform.tfstate` is created in the project directory. This file is a JSON data structure mapping your real AWS infrastructure to the resource definitions from your configuration files. The directory now appears as:

```bash
$ ls terraform-aws-project
main.tf  variables.tf  provider.tf  terraform.tfstate
```

Inspecting `terraform.tfstate` reveals a detailed record of your infrastructure, including resource IDs, provider information, and resource attributes:

```json
{
  "version": 4,
  "terraform_version": "1.5.0",
  "serial": 1,
  "lineage": "e35dde72-a943-de50-3c8b-1df8986e5a31",
  "outputs": {},
  "resources": [
    {
      "mode": "managed",
      "type": "aws_security_group",
      "name": "web_sg",
      "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
      "instances": [
        {
          "schema_version": 1,
          "attributes": {
            "arn": "arn:aws:ec2:us-east-1:123456789:security-group/sg-0987654321fedcba0",
            "description": "Security group for web server",
            "egress": [
              {
                "cidr_blocks": ["0.0.0.0/0"],
                "from_port": 0,
                "protocol": "-1",
                "to_port": 0
              }
            ],
            "id": "sg-0987654321fedcba0",
            "ingress": [
              {
                "cidr_blocks": ["0.0.0.0/0"],
                "from_port": 80,
                "protocol": "tcp",
                "to_port": 80
              }
            ],
            "name": "web-security-group",
            "owner_id": "123456789",
            "tags": {
              "Name": "web-security-group"
            },
            "vpc_id": "vpc-1a2b3c4d"
          }
        }
      ]
    },
    {
      "mode": "managed",
      "type": "aws_instance",
      "name": "web_server",
      "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
      "instances": [
        {
          "schema_version": 1,
          "attributes": {
            "ami": "ami-0c55b159cbfafe1f0",
            "arn": "arn:aws:ec2:us-east-1:123456789:instance/i-0c55b159cbfafe1f0",
            "availability_zone": "us-east-1a",
            "id": "i-0c55b159cbfafe1f0",
            "instance_state": "running",
            "instance_type": "t2.micro",
            "private_ip": "10.0.1.42",
            "public_ip": "54.123.45.67",
            "tags": {
              "Name": "my-web-server"
            },
            "vpc_id": "vpc-1a2b3c4d"
          }
        }
      ]
    }
  ]
}
```

This state file is the single source of truth for Terraform. It is used during subsequent commands like `terraform plan` and `terraform apply` to determine if any changes to the infrastructure are required.

---

## Updating the Configuration

Consider updating the configuration in `main.tf` to add an IAM role for the EC2 instance:

```hcl
resource "aws_iam_role" "ec2_role" {
  name = "ec2-web-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_instance" "web_server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  iam_instance_profile = aws_iam_role.ec2_role.name

  tags = {
    Name = "my-web-server"
  }
}
```

After this change, running `terraform apply` causes Terraform to refresh the state and detect a difference between the new configuration and the existing state. Consequently, Terraform decides the instance must be replaced:

```bash
$ terraform apply
aws_security_group.web_sg: Refreshing state... [id=sg-0987654321fedcba0]
aws_instance.web_server: Refreshing state... [id=i-0c55b159cbfafe1f0]
aws_iam_role.ec2_role: Creating...
aws_iam_role.ec2_role: Creation complete after 1s [id=ec2-web-server-role]

Terraform will perform the following actions:

  # aws_instance.web_server must be replaced
  -/+ resource "aws_instance" "web_server" {
        ami                 = "ami-0c55b159cbfafe1f0"
        instance_type       = "t2.micro"
      ~ id                  = "i-0c55b159cbfafe1f0" -> (known after apply)
      + iam_instance_profile = "ec2-web-server-role" # forces replacement
        tags = {
            "Name" = "my-web-server"
          }
      }

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

Enter a value: yes

aws_instance.web_server: Destroying... [id=i-0c55b159cbfafe1f0]
aws_instance.web_server: Destruction complete after 3s
aws_instance.web_server: Creating...
aws_instance.web_server: Creation complete after 30s [id=i-1a2b3c4d5e6f7g8h9]

Apply complete! Resources: 1 added, 0 changed, 1 destroyed.
```

After applying these changes, Terraform deletes the old instance and creates a new one with a different unique ID. The updated `terraform.tfstate` now reflects the new state with the IAM role attached:

```json
{
  "version": 4,
  "terraform_version": "1.5.0",
  "serial": 2,
  "lineage": "e35dde72-a943-de50-3c8b-1df8986e5a31",
  "outputs": {},
  "resources": [
    {
      "mode": "managed",
      "type": "aws_iam_role",
      "name": "ec2_role",
      "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
      "instances": [
        {
          "schema_version": 0,
          "attributes": {
            "arn": "arn:aws:iam::123456789:role/ec2-web-server-role",
            "id": "ec2-web-server-role",
            "name": "ec2-web-server-role"
          }
        }
      ]
    },
    {
      "mode": "managed",
      "type": "aws_instance",
      "name": "web_server",
      "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
      "instances": [
        {
          "schema_version": 1,
          "attributes": {
            "ami": "ami-0c55b159cbfafe1f0",
            "id": "i-1a2b3c4d5e6f7g8h9",
            "iam_instance_profile": "ec2-web-server-role",
            "instance_type": "t2.micro",
            "private_ip": "10.0.1.55",
            "public_ip": "54.234.12.34",
            "tags": {
              "Name": "my-web-server"
            }
          }
        }
      ]
    }
  ]
}
```

Now that the configuration file and the state file are in sync, any subsequent runs of `terraform apply` will report that no changes are necessary.

---

## Understanding State Importance

The state file serves critical purposes:

✅ **Resource Tracking** — Knows which resources exist in AWS
✅ **Change Detection** — Identifies what needs to be created, modified, or destroyed
✅ **Dependency Management** — Understands relationships between resources
✅ **Performance** — Avoids querying AWS every time you run terraform plan
✅ **Consistency** — Ensures configuration and reality stay in sync

---

## Key Concepts

| Term | Meaning |
|------|---------|
| **State File** | JSON record of your infrastructure (terraform.tfstate) |
| **Refresh** | Terraform queries AWS to check current resource status |
| **Plan** | Shows what changes Terraform will make |
| **Apply** | Creates, modifies, or destroys resources to match configuration |
| **Drift** | When real infrastructure differs from state file |

---

## Summary

In this lesson, we explored how Terraform leverages a state file—initially created during the first successful apply—to track and manage real AWS infrastructure. This state file serves as the authoritative record for your resources and is essential for Terraform to efficiently plan and apply configuration changes.

Managing your Terraform state is crucial for ensuring consistent and predictable infrastructure behavior. In upcoming lessons, we will further explore the significance of state management and discuss best practices for handling it effectively.

---

## Hands-On Lab

The [`hands-on-lab/`](hands-on-lab/) folder walks through this lesson's example end to end:

- [`initial-infrastructure/`](hands-on-lab/initial-infrastructure/) — the starting config (security group + EC2 instance). Run `terraform init`, `terraform plan`, and `terraform apply` here first and inspect the generated `terraform.tfstate`.
- [`updated-with-iam-role/`](hands-on-lab/updated-with-iam-role/) — the same config with the IAM role added. Apply this next (in its own directory/state) to see Terraform force-replace the EC2 instance and watch `serial` bump in the state file.

---

## Official Resources

- [Terraform State Documentation](https://www.terraform.io/language/state)
- [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform CLI Reference](https://www.terraform.io/cli)
