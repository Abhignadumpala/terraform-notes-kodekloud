# AWS Resource Code: Basic Building Blocks

My ready-to-use Terraform code for the basic AWS resources. One file per resource, so I can copy the one I need. Together, the files build one small working setup: a VPC with a public web server, an S3 bucket and an IAM user.

[← Back to main README](../README.md)

---

## What gets built

```
AWS (us-east-1)
└── VPC  10.0.0.0/16                         vpc.tf
    ├── Internet gateway                     internet_gateway.tf
    ├── Public subnet   10.0.1.0/24 (1a)     subnet.tf
    │   ├── Route table: 0.0.0.0/0 → IGW     route_table.tf
    │   └── EC2 t3.micro (Amazon Linux)      ec2.tf
    │       └── Security group: 22, 80 in    security_group.tf
    └── Private subnet  10.0.2.0/24 (1b)     subnet.tf

S3 bucket (versioning on, no public access)  s3.tf
IAM user → IAM group → ReadOnlyAccess policy iam.tf
```

---

## Files

| File | What it creates | Official docs |
|------|-----------------|---------------|
| [provider.tf](provider.tf) | Tells Terraform to use AWS, in `us-east-1` | [AWS provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) |
| [vpc.tf](vpc.tf) | My own private network, `10.0.0.0/16` | [aws_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) |
| [subnet.tf](subnet.tf) | 1 public + 1 private subnet | [aws_subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) |
| [internet_gateway.tf](internet_gateway.tf) | The door between the VPC and the internet | [aws_internet_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) |
| [route_table.tf](route_table.tf) | Route `0.0.0.0/0 → internet gateway`, joined to the public subnet | [aws_route_table](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) · [aws_route_table_association](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) |
| [security_group.tf](security_group.tf) | Firewall: SSH 22 + HTTP 80 in, all out | [aws_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) · [ingress_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) · [egress_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) |
| [ec2.tf](ec2.tf) | Finds the latest Amazon Linux 2023 AMI + one `t3.micro` server | [aws_ami (data)](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) · [aws_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) |
| [s3.tf](s3.tf) | S3 bucket + versioning + block public access | [aws_s3_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) · [versioning](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) · [public_access_block](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) |
| [iam.tf](iam.tf) | IAM user, group, user-in-group, ReadOnlyAccess on the group | [aws_iam_user](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user) · [aws_iam_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_group) · [membership](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_group_membership) · [policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_group_policy_attachment) |
| [outputs.tf](outputs.tf) | Prints the VPC ID, server public IP and bucket name | [Output values](https://developer.hashicorp.com/terraform/language/values/outputs) |

---

## The basic pattern

Every AWS resource follows the same shape:

```hcl
resource "<resource_type>" "<my_name>" {
  argument = value

  tags = {
    Name = "name I see in the AWS console"
  }
}
```

| Part | Example | Meaning |
|------|---------|---------|
| `resource_type` | `aws_vpc` | What to create. Comes from the AWS provider docs |
| `my_name` | `main` | My name for it **inside Terraform only** |
| Reference | `aws_vpc.main.id` | Use another resource's value. This also tells Terraform the order: VPC first, then subnet |

**How the files connect:**

| This resource | Uses | So Terraform creates first |
|---------------|------|----------------------------|
| subnet | `aws_vpc.main.id` | VPC |
| route table | `aws_internet_gateway.main.id` | internet gateway |
| EC2 | `aws_subnet.public.id`, `aws_security_group.web.id`, `data.aws_ami.amazon_linux.id` | subnet, security group, AMI lookup |
| SG rules | `aws_security_group.web.id` | security group |
| IAM membership | `aws_iam_user.dev.name`, `aws_iam_group.developers.name` | user and group |

---

## Things I keep in mind

| Resource | Point |
|----------|-------|
| Subnet | **Public** only because its route table sends `0.0.0.0/0` to an internet gateway. The subnet itself has no "public" switch |
| Security group | Each rule is its own `aws_vpc_security_group_ingress_rule` / `egress_rule` resource, one CIDR per rule. I don't use inline `ingress {}` / `egress {}` blocks, and never mix both styles: mixing makes rules get overwritten |
| Security group | `ip_protocol = "-1"` = all protocols, all ports |
| SSH rule | `0.0.0.0/0` is for practice only. For real use: my own IP, e.g. `"1.2.3.4/32"` |
| EC2 | AMI comes from a `data "aws_ami"` lookup, never a hard-coded ID (IDs differ per region) |
| S3 | Bucket names must be unique, so I use `bucket_prefix` and AWS adds a random ending |
| S3 | Versioning and public-access settings are **separate resources**, not arguments of `aws_s3_bucket` |
| IAM | Permissions go on the **group**; users get them by joining the group |

---

## How I run it

```bash
cd aws-resource-code
terraform init        # download the AWS provider
terraform plan        # preview: what will be created
terraform apply       # create it (type yes)
terraform output      # vpc_id, web_server_public_ip, bucket_name
terraform destroy     # delete everything when done, so I don't pay for it
```

Needs AWS credentials on my laptop first (`aws configure`).

To use just one resource in another project, I copy that file and change the references (for example `aws_vpc.main.id`) to match that project.

---

## Summary

- ✅ One file per AWS resource; together they build a VPC, public web server, S3 bucket and IAM user
- ✅ `resource "type" "name" { ... }` is the same shape for every resource; `type.name.attribute` connects them and sets the order
- ✅ Public subnet = route table with `0.0.0.0/0 → internet gateway`
- ✅ Security group rules as separate resources, one CIDR per rule
- ✅ AMI from a data source, `t3.micro`, S3 with `bucket_prefix`, IAM permissions on groups
- ⚠️ Run `terraform destroy` after practice: the EC2 instance costs money while it runs

## Key Takeaway

Every AWS resource in Terraform is the same block shape. The real skill is the **references** between them: subnet → VPC, route table → internet gateway, EC2 → subnet + security group. Get those right and Terraform builds everything in the right order by itself.
