# 📘 Module 9.3: Terraform Import

> In this note, I explain how to import existing infrastructure into my Terraform configuration. Usually I create and manage resources with Terraform. But in many real-world projects, some resources are made with other tools like the AWS Management Console or Ansible. Importing these resources into Terraform lets me handle their provisioning, updates, and deletion in one place.

---

## Overview

Picture one AWS account where different tools made different resources: Terraform made some EC2 instances, Ansible made others, and someone clicked together a DynamoDB table, an S3 bucket, Route 53 records, EBS volumes, and a VPC in the AWS Management Console. Terraform only knows about the resources it made itself.

So the question is: how do I bring resources made outside Terraform under Terraform's direct management?

---

## Accessing Existing Resources Using Data Sources

First, I can use data sources to read details from resources that my configuration doesn't manage. Data sources let me read attributes and use existing infrastructure in my configuration, without letting Terraform update or delete those resources.

For example, the configuration below reads attributes of an existing AWS instance using its instance ID:

```hcl
data "aws_instance" "newserver" {
  instance_id = "i-026e13be10d5326f7"
}

output "newserver" {
  value = data.aws_instance.newserver.public_ip
}
```

Official docs: [`aws_instance` data source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/instance).

When I run:

```bash
$ terraform apply

data.aws_instance.newserver: Reading...
data.aws_instance.newserver: Read complete after 1s [id=i-026e13be10d5326f7]

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

newserver = "15.223.1.176"
```

Terraform outputs the instance's public IP, but the instance is still not managed by Terraform, because I only read it as a data source.

---

## Importing an Existing Resource into Terraform

To fully control an existing resource, I need to import it into Terraform's state. The syntax for the import command is:

```plaintext
# terraform import <resource_type>.<resource_name> <attribute>
$ terraform import aws_instance.webserver-2 i-026e13be10d5326f7
```

> ⚠️ Before running the import command, the matching resource block must exist in my configuration. If it isn't defined, Terraform returns an error.

If the resource block hasn't been created, I see this error:

```plaintext
Error: resource address "aws_instance.webserver-2" does not exist in the configuration.

Before importing this resource, please create its configuration in the root module. For example:
resource "aws_instance" "webserver-2" {
  # (resource arguments)
}
```

`terraform import` only updates the state file. It does not write or change any configuration files, so I create the resource block first.

Official docs: [`terraform import`](https://developer.hashicorp.com/terraform/cli/commands/import).

### Step 1: Create an Empty Resource Block

I start by defining an empty resource block in my configuration file:

```hcl
resource "aws_instance" "webserver-2" {
  # (resource arguments)
}
```

### Step 2: Run the Import Command

With the empty block in place, I run the import command again. The output looks like this:

```bash
$ terraform import aws_instance.webserver-2 i-026e13be10d5326f7
aws_instance.webserver-2: Importing from ID "i-026e13be10d5326f7"...
aws_instance.webserver-2: Import prepared!
  Prepared aws_instance for import
aws_instance.webserver-2: Refreshing state... [id=i-026e13be10d5326f7]

Import successful!
```

The command adds the resource to my Terraform state file, so Terraform can manage it from here on.

### Step 3: Complete the Resource Configuration

Next, I fill in the resource block with its settings. I can get the values from the AWS Management Console, or from the state with `terraform state show aws_instance.webserver-2`. For example:

```hcl
resource "aws_instance" "webserver-2" {
  ami                    = "ami-0edab43b6fa892279"
  instance_type          = "t3.micro"
  key_name               = "ws"
  vpc_security_group_ids = ["sg-0a543f25009e14628"]
}
```

The values must match the real instance. If they don't, the next `apply` changes the real instance to match my code, and a different `ami` even makes Terraform destroy and recreate it.

Running `terraform plan` now confirms that my configuration matches the imported infrastructure:

```bash
$ terraform plan
aws_instance.webserver-2: Refreshing state... [id=i-026e13be10d5326f7]

No changes. Your infrastructure matches the configuration.
```

> 💡 This output confirms that the resource was imported successfully. From now on, I manage any changes to this instance by editing this configuration and following the normal Terraform workflow: init, plan, and apply.

---

## Importing with an `import` Block

The recommended way to import is an `import` block in my configuration, instead of the `terraform import` command. It needs two things: `to` (the resource address) and `id` (the real resource ID):

```hcl
import {
  to = aws_instance.webserver-2
  id = "i-026e13be10d5326f7"
}
```

The difference from the command: the import shows up in `terraform plan` first, and nothing changes until I run `terraform apply`. Terraform can also write the resource block for me, so I can skip Steps 1 and 3:

```bash
$ terraform plan -generate-config-out=generated.tf
```

```plaintext
  # aws_instance.webserver-2 will be imported
  # (config will be generated)
Plan: 1 to import, 0 to add, 0 to change, 0 to destroy.

Warning: Config generation is experimental
```

Terraform writes the full `resource "aws_instance" "webserver-2"` block into `generated.tf`. I review it, remove what I don't need, and then run:

```bash
$ terraform apply
Apply complete! Resources: 1 imported, 0 added, 0 changed, 0 destroyed.
```

> ⚠️ `-generate-config-out` is still experimental, and the file name must not exist yet — otherwise Terraform stops with `Target generated file already exists`. After the import, I can remove the `import` block; I tested leaving it in and the next plan still said "No changes."

Official docs: [`import` block](https://developer.hashicorp.com/terraform/language/block/import) and [Generating configuration](https://developer.hashicorp.com/terraform/language/import/generating-configuration).

---

## Summary Table

| Method | Action | Description |
|--------|--------|-------------|
| `data "aws_instance"` | Read an existing resource | Reads attributes only; Terraform can't change or delete it |
| `terraform import` | Import into state | Adds the resource to state; I must write the resource block myself |
| `import` block | Import through plan and apply | Recommended way; shown in the plan first |
| `terraform plan -generate-config-out` | Generate the resource block | Writes the resource block for an `import` block (experimental) |
| `terraform plan` | Verify the import | "No changes" means my code matches the real resource |

---

## Summary

- ✅ Data sources read existing resources but don't manage them
- ✅ Import adds an existing resource to Terraform's state without recreating it
- ⚠️ `terraform import` needs the resource block to exist first, and it doesn't write any code
- ✅ The `import` block is the recommended way — it shows in the plan and can generate the code
- ✅ A clean `terraform plan` ("No changes") means the import is complete

---

## Key Takeaway

**To bring a resource under Terraform: import it, make the resource block match the real resource, and run `terraform plan` until it says "No changes."**

- ✅ After that, the resource is managed like any other: init, plan, apply
- ⚠️ If the plan shows changes after an import, the next `apply` changes the real resource — I fix the code first

---

## Practice & Next Steps

Create an EC2 instance by hand in the AWS Management Console. Read it with a `data "aws_instance"` block first, then import it with `terraform import` (Steps 1–3). Remove it from state with `terraform state rm aws_instance.webserver-2` (this doesn't delete the real instance) and import it again, this time with an `import` block and `-generate-config-out`, to compare the two ways.

That closes out Module 9.
