# module 2.1: Installing Terraform

In this lesson, you'll learn how to install Terraform. Terraform is distributed as a single binary that you download and place in your system's PATH, then verify with a version check. Terraform supports Windows, macOS, and a range of Linux distributions — for this lesson, I'm installing on Ubuntu Linux with Terraform v1.15.8.

## Installing Terraform on Linux (Ubuntu)

```bash
sudo apt-get update
sudo apt-get install -y gnupg software-properties-common curl
```

```bash
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
```

```bash
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
```

```bash
sudo apt-get update
sudo apt-get install terraform
```

Verify the installation:
```bash
terraform version
```
```
Terraform v1.15.8
on linux_amd64
```
<img width="1799" height="427" alt="Screenshot From 2026-08-14 01-14-34" src="https://github.com/user-attachments/assets/66b45546-1b75-469f-a578-09e05fa1afdf" />


## Working with Terraform

Once installed, you write `.tf` configuration files using HashiCorp Configuration Language (HCL). These are plain text files, editable in any editor.

Example — an AWS EC2 instance resource:
```hcl
resource "aws_instance" "webserver" {
  ami           = "ami-0c2f25c1f66a1ff4d"
  instance_type = "t2.micro"
}
```

## Understanding Terraform Resources

A **resource** is an object Terraform manages — this could be a virtual machine, a storage bucket, an IAM role, a local file, or many other things.

| Resource Type | Description               | Example         |
|----------------|---------------------------|------------------|
| EC2 Instance   | Virtual machine on AWS    | `aws_instance`   |
| S3 Bucket      | Cloud storage on AWS      | `aws_s3_bucket`  |
| IAM Role       | Access management on AWS  | `aws_iam_role`   |

Terraform can provision hundreds of resource types across multiple providers (AWS, GCP, Azure) in the same configuration, and can also manage on-premises infrastructure.

## Starting simple

Before jumping into real cloud resources, it helps to practice with two simple, free resource types:

- A **local file** resource — creates a file on your own machine.
- A **random pet** resource — generates a random name, useful for understanding resource lifecycle without touching any cloud account.

These two are good for getting comfortable with core Terraform concepts — how resources are created, tracked in state, and destroyed — before moving on to real AWS/Azure/GCP infrastructure.

---
**Reference:** [Terraform Install Docs — developer.hashicorp.com](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
