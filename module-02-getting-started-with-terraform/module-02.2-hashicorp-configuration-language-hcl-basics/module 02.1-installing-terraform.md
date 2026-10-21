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

## Connecting Terraform to AWS

Installing Terraform alone isn't enough to create anything on AWS. Terraform has to know **which account** to log in to and **which region** to use. Without that, `terraform plan` on an AWS resource fails with a "no valid credential sources" or "missing region" error.

I need three things before the EC2 example below can work:

| Step | What | Why |
|------|------|-----|
| 1 | Install the **AWS CLI** | Gives me the `aws configure` command |
| 2 | Run **`aws configure`** with an IAM user's access key | Saves the credentials in `~/.aws/credentials` |
| 3 | Add a **`provider "aws"`** block with the region | Tells Terraform to use AWS, and where |

**1. Install the AWS CLI (Ubuntu)**
```bash
sudo apt-get install -y unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
```

**2. Configure the credentials**

I create an access key for an IAM user in the AWS console (IAM → Users → Security credentials → Create access key), then:
```bash
aws configure
```
```
AWS Access Key ID [None]: <your-access-key-id>
AWS Secret Access Key [None]: <your-secret-access-key>
Default region name [None]: us-east-1
Default output format [None]: json
```

Check that it works. This prints my account ID and user, so the credentials are valid:
```bash
aws sts get-caller-identity
```

**3. Tell Terraform to use AWS**
```hcl
provider "aws" {
  region = "us-east-1"
}
```

Terraform's AWS provider reads the same `~/.aws/credentials` file that the CLI uses, so I **never** write the access key inside a `.tf` file. `terraform init` then downloads the AWS provider plugin.

> ⚠️ The access key is like a password. Never commit `~/.aws/credentials` or put `access_key` / `secret_key` in `.tf` files.

More detail: [6.3 Programmatic access](../../module-06-aws-services-for-terraform/module-06.3-programmatic-access/README.md#configuring-the-aws-cli) (AWS CLI and `aws configure`) and [6.4 AWS IAM with Terraform](../../module-06-aws-services-for-terraform/module-06.4-aws-iam-with-terraform/README.md#best-practices-for-managing-credentials) (provider block and credential best practices).


## Working with Terraform

Once installed, you write `.tf` configuration files using HashiCorp Configuration Language (HCL). These are plain text files, editable in any editor.

Example — an AWS EC2 instance resource (works only after [Connecting Terraform to AWS](#connecting-terraform-to-aws)):
```hcl
provider "aws" {
  region = "us-east-1"
}

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
