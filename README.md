# Terraform Notes (KodeKloud Course)

My study notes, hands-on labs and projects from the **KodeKloud Terraform** course. I wrote them class by class as I went, in my own words, with screenshots from the labs I ran.

> 🧪 **Want to do the AWS labs step by step?** They're cleaned up, in order, in one place: [terraform-aws-labs](https://github.com/Abhignadumpala/terraform-aws-labs) (setup → EC2, SG, IAM, S3, DynamoDB → count/for_each/lifecycle → state → provisioners → modules project). This repo keeps the theory and my original class notes.

---

## 📌 Read this first: "module" in folder names = my class, NOT a Terraform module

I named each class folder **`module-01`, `module-02`, `module-03`…** as I went through the course. Here **"module" just means a class / lesson number**.

**This is not the Terraform modules concept.** Terraform modules (reusable `.tf` code you call with a `module "name" {}` block) are covered in their own class: [Module 10: Terraform Modules](#module-10--terraform-modules), and in my [AWS modules project](./terraform-projects/terraform-modules-multi-env/README.md).

| You see | It means |
|---------|----------|
| `module-03-terraform-basics/` | **Class 3** of the course: Terraform basics |
| `module-03.7-resource-attributes/` | **Lesson 7** inside class 3 |
| `module "vpc" { source = "./modules/vpc" }` | A real **Terraform module** (only in Module 10 and the projects) |

---

## Table of Contents

1. [Learning path: no AWS → AWS → projects](#learning-path-no-aws--aws--projects)
2. [How each folder is organised](#how-each-folder-is-organised)
3. [Module 01: Introduction to IaC](#module-01--introduction-to-infrastructure-as-code)
4. [Module 02: Getting Started with Terraform](#module-02--getting-started-with-terraform)
5. [Module 03: Terraform Basics](#module-03--terraform-basics)
6. [Module 04: Terraform State](#module-04--terraform-state)
7. [Module 05: Working with Terraform](#module-05--working-with-terraform)
8. [Module 06: AWS Services with Terraform](#module-06--aws-services-with-terraform)
9. [Module 07: Remote State](#module-07--remote-state)
10. [Module 08: EC2 and Provisioners](#module-08--ec2-and-provisioners)
11. [Module 09: Import, Taint and Debugging](#module-09--import-taint-and-debugging)
12. [Module 10: Terraform Modules](#module-10--terraform-modules)
13. [Module 11: Terraform Workspaces](#module-11--terraform-workspaces)
14. [Projects](#projects)
15. [Standalone notes](#standalone-notes)

---

## Learning path: no AWS → AWS → projects

| Stage | Classes | What I practised |
|-------|---------|------------------|
| 1. Basics, **no AWS** | Module 01–02 | What IaC is, installing Terraform, HCL, `local_file` labs (create, update, destroy a file) |
| 2. Core Terraform **on AWS** | Module 03–05 | Providers, variables, attributes, dependencies, outputs, state, lifecycle, count, for_each (EC2, SG, IAM, S3) |
| 3. AWS services | Module 06–08 | IAM, S3, DynamoDB, S3 remote backend, EC2 with provisioners |
| 4. Advanced | Module 09–11 | Import, taint, debugging, **Terraform modules**, workspaces |
| 5. Projects | `terraform-projects/` | Real end-to-end builds: dev/prod EC2 sizing, nginx app with reusable modules (dev, staging, prod) |

> **Before any AWS lab:** follow [Lab Setup: connect Terraform to AWS and create your first resources](./lab-setup-terraform-aws/README.md) (IAM user → access key → `aws configure` → install Terraform → first EC2 + SG lab).

---

## How each folder is organised

```
module-0N-<class-topic>/              ← one class
└── module-0N.M-<lesson-topic>/       ← one lesson in that class
    ├── <lesson>.md / README.md       ← my notes
    ├── images/                       ← screenshots from my labs
    ├── hands-on-lab/                 ← the lab I ran (.tf files + lab README)
    └── interview-questions/          ← interview Q&A (some lessons)

terraform-projects/<project>/         ← standalone projects (not tied to one class)
```

| Icon | Meaning |
|------|---------|
| 📝 | Notes |
| 🧪 | Hands-on lab |
| ❓ | Interview questions |
| ☁️ | Uses real AWS resources |

---

## Module 01 — Introduction to Infrastructure as Code

| Lesson | Contains |
|--------|----------|
| [1.1 Challenges with traditional IT infrastructure](./module-01-introduction-to-infrastructure-as-code/module-01.1-challenges-with-traditional-it-infrastructure/Challenges-with-traditional-%20IT-infrastructure.md) | 📝 Traditional IT vs Cloud vs IaC |
| [1.2 Types of IaC tools](./module-01-introduction-to-infrastructure-as-code/module-01.2-types-of-iac-tools/types-of-iac-tools.md) | 📝 Configuration management vs server templating vs provisioning tools |
| [1.3 Why Terraform](./module-01-introduction-to-infrastructure-as-code/module-01.3-why-terraform/why-terraform.md) | 📝 Why Terraform over other tools |

## Module 02 — Getting Started with Terraform

No AWS here: all labs use the `local_file` resource.

| Lesson | Contains |
|--------|----------|
| [2.1 Installing Terraform](./module-02-getting-started-with-terraform/module-02.2-hashicorp-configuration-language-hcl-basics/module%2002.1-installing-terraform.md) | 📝 Install on Ubuntu, connecting Terraform to AWS, links to all AWS practice labs |
| [2.2 HCL basics: local file](./module-02-getting-started-with-terraform/module-02.2-hashicorp-configuration-language-hcl-basics/module%2002.2-hcl-basics-local-file.md) | 📝 🧪 Block anatomy, `init` / `plan` / `apply` on a local file |
| [2.3 Update and destroy](./module-02-getting-started-with-terraform/module-02.2-hashicorp-configuration-language-hcl-basics/module-02.3-update-and-destroy-local-file.md) | 📝 🧪 Changing and destroying the file |

## Module 03 — Terraform Basics

| Lesson | Contains |
|--------|----------|
| [3.1 Using Terraform providers](./module-03-terraform-basics/module-03.1-using-terraform-providers/using-terraform-providers.md) | 📝 Provider tiers, `terraform init`, source addresses, version lock file |
| [3.2 Configuration directory](./module-03-terraform-basics/module-03.2-configuration-directory/configuration-directory.md) | 📝 How Terraform reads all `.tf` files in a folder |
| [3.3 Multiple providers](./module-03-terraform-basics/module-03.3-multiple-providers/multiple-providers.md) | 📝 More than one provider in one config |
| [3.4 Input variables](./module-03-terraform-basics/module-03.4-using-input-variables/input-variables.md) | 📝 `variable` blocks |
| [3.5 Understanding the variable block](./module-03-terraform-basics/module-03.5-understanding-the-variable-block/understanding-variable-block.md) | 📝 🧪 [Lab](./module-03-terraform-basics/module-03.5-understanding-the-variable-block/hands-on-lab/hands-on-lab-understanding-variable-block.md): type, default, description |
| [3.6 Using variables](./module-03-terraform-basics/module-03.6-using-variables-in-terraform/Using-Variables-in-Terraform.md) | 📝 🧪 ☁️ [Variables with AWS infrastructure](./module-03-terraform-basics/module-03.6-using-variables-in-terraform/using-variables-with-aws-infrastructure/README.md) |
| [3.7 Resource attributes](./module-03-terraform-basics/module-03.7-resource-attributes/module-03.7-resource-attributes.md) | 📝 🧪 ☁️ [Linking EC2 to a security group](./module-03-terraform-basics/module-03.7-resource-attributes/handson-labs/module-03.7-hands-on-lab-ec2-sg-linking.md) |
| [3.8 Resource dependencies](./module-03-terraform-basics/module-03.8-resource-dependencies-in-terraform/README.md) | 📝 🧪 ☁️ [Implicit](./module-03-terraform-basics/module-03.8-resource-dependencies-in-terraform/handson-labs/implicit-dependency-lab/README.md) and [explicit](./module-03-terraform-basics/module-03.8-resource-dependencies-in-terraform/handson-labs/explicit-dependency-lab/README.md) dependency labs |
| [3.9 Output variables](./module-03-terraform-basics/module-03.9-output-variables-in-terraform/README.md) | 📝 `output` blocks |

## Module 04 — Terraform State

| Lesson | Contains |
|--------|----------|
| [4.0 Introduction to state](./module-04-terraform-state/module-04.0-introduction-to-terraform-state/README.md) | 📝 🧪 ☁️ State file with EC2, SG, IAM role · [troubleshooting: SG attachment](./module-04-terraform-state/troubleshooting-notes/module-04.0-sg-attachment.md) |
| [4.1 Purpose of state](./module-04-terraform-state/module-04.1-purpose-of-state/README.md) | 📝 Maps config to real resources, tracks dependencies, team collaboration |
| [4.2 State considerations](./module-04-terraform-state/module-04.2-terraform-state-considerations/README.md) | 📝 🧪 ☁️ [S3 state bucket + app](./module-04-terraform-state/module-04.2-terraform-state-considerations/hands-on-lab/README.md) |
| [4.3 State complete guide](./module-04-terraform-state/module-04.3-state-complete-guide/README.md) | 📝 Everything about state in one page |
| [4.4 State drift](./module-04-terraform-state/module-04.4-state-drift/README.md) | 📝 When real infra differs from state |
| [4.5 State loss and recovery](./module-04-terraform-state/module-04.5-state-loss-and-recovery/README.md) | 📝 What to do when state is lost |

## Module 05 — Working with Terraform

| Lesson | Contains |
|--------|----------|
| [5.1 Terraform commands](./module-05-working-with-terraform/module-05.1-terraform-commands/README.md) | 📝 validate, fmt, show, providers, output, refresh, graph |
| [5.2 Mutable vs immutable](./module-05-working-with-terraform/module-05.2-mutable-vs-immutable-infrastructure/README.md) | 📝 🧪 ☁️ [Lab](./module-05-working-with-terraform/module-05.2-mutable-vs-immutable-infrastructure/hands-on-lab/README.md) · ❓ [Questions](./module-05-working-with-terraform/module-05.2-mutable-vs-immutable-infrastructure/interview-questions/README.md) |
| [5.3 Lifecycle rules](./module-05-working-with-terraform/module-05.3-lifecycle-rules/README.md) | 📝 🧪 ☁️ [Lab](./module-05-working-with-terraform/module-05.3-lifecycle-rules/hands-on-lab/README.md): create_before_destroy, prevent_destroy, ignore_changes |
| [5.4 Data sources](./module-05-working-with-terraform/module-05.4-datasources/README.md) | 📝 Reading existing resources |
| [5.5 Meta-arguments](./module-05-working-with-terraform/module-05.5-meta-arguments/README.md) | 📝 depends_on, lifecycle, count |
| [5.6 count](./module-05-working-with-terraform/module-05.6-count/README.md) | 📝 🧪 ☁️ [Lab](./module-05-working-with-terraform/module-05.6-count/hands-on-lab/README.md): multiple EC2 instances |
| [5.7 for_each](./module-05-working-with-terraform/module-05.7-for-each/README.md) | 📝 🧪 ☁️ [Lab](./module-05-working-with-terraform/module-05.7-for-each/hands-on-lab/README.md): EC2 instances by name |
| [5.8 Version constraints](./module-05-working-with-terraform/module-05.8-version-constraints/README.md) | 📝 Pinning provider versions |
| [5.9 The terraform block](./module-05-working-with-terraform/module-05.9-the-terraform-block/README.md) | 📝 required_version, required_providers |
| [5.10 Built-in functions](./module-05-working-with-terraform/module-05.10-built-in-functions/README.md) | 📝 Common functions |
| [5.11 Locals](./module-05-working-with-terraform/module-05.11-locals/README.md) | 📝 `locals` block |

## Module 06 — AWS Services with Terraform

| Lesson | Contains |
|--------|----------|
| [6.1 Introduction to IAM](./module-06-aws-services-for-terraform/module-06.1-introduction-to-iam/README.md) | 📝 Users, groups, policies, roles · ❓ [Questions](./module-06-aws-services-for-terraform/module-06.1-introduction-to-iam/interview-questions/README.md) |
| [6.2 Demo IAM](./module-06-aws-services-for-terraform/module-06.2-demo-iam/README.md) | 📝 🧪 ☁️ [IAM in the console](./module-06-aws-services-for-terraform/module-06.2-demo-iam/hands-on-lab/README.md) |
| [6.3 Programmatic access](./module-06-aws-services-for-terraform/module-06.3-programmatic-access/README.md) | 📝 AWS CLI and `aws configure` |
| [6.4 AWS IAM with Terraform](./module-06-aws-services-for-terraform/module-06.4-aws-iam-with-terraform/README.md) | 📝 🧪 ☁️ [IAM user, policy, attachment](./module-06-aws-services-for-terraform/module-06.4-aws-iam-with-terraform/hands-on-lab/README.md) |
| [6.5 Introduction to S3](./module-06-aws-services-for-terraform/module-06.5-introduction-to-s3/README.md) | 📝 Buckets, objects, policies |
| [6.6 S3 with Terraform](./module-06-aws-services-for-terraform/module-06.6-s3-with-terraform/README.md) | 📝 🧪 ☁️ [Bucket, object, policy](./module-06-aws-services-for-terraform/module-06.6-s3-with-terraform/hands-on-lab/README.md) · ❓ [Questions](./module-06-aws-services-for-terraform/module-06.6-s3-with-terraform/interview-questions/README.md) |
| [6.7 Introduction to DynamoDB](./module-06-aws-services-for-terraform/module-06.7-introduction-to-dynamodb/README.md) | 📝 Tables, items, keys |
| [6.8 Demo DynamoDB](./module-06-aws-services-for-terraform/module-06.8-demo-dynamodb/README.md) | 📝 ☁️ Table in the console |
| [6.9 DynamoDB with Terraform](./module-06-aws-services-for-terraform/module-06.9-dynamodb-with-terraform/README.md) | 📝 🧪 ☁️ [Table + items](./module-06-aws-services-for-terraform/module-06.9-dynamodb-with-terraform/hands-on-lab/README.md) |

## Module 07 — Remote State

| Lesson | Contains |
|--------|----------|
| [7.1 S3 remote backend and locking](./module-07-remote-state/module-07.1-s3-remote-backend-and-locking/README.md) | 📝 🧪 ☁️ [Migrating state to S3](./module-07-remote-state/module-07.1-s3-remote-backend-and-locking/hands-on-lab/README.md) |
| [7.2 Cross-stack state sharing](./module-07-remote-state/module-07.2-cross-stack-state-sharing/README.md) | 📝 🧪 ☁️ [Network + compute stacks](./module-07-remote-state/module-07.2-cross-stack-state-sharing/hands-on-lab/README.md) |
| [7.3 State commands](./module-07-remote-state/module-07.3-terraform-state-commands/README.md) | 📝 🧪 ☁️ [state list / show / mv / pull / rm](./module-07-remote-state/module-07.3-terraform-state-commands/hands-on-lab/README.md) |

## Module 08 — EC2 and Provisioners

| Lesson | Contains |
|--------|----------|
| [8.1 Introduction to AWS EC2](./module-08-terraform-provisioners/module-08.1-introduction-to-aws-ec2/README.md) | 📝 AMIs, instance types, EBS, user data, access |
| [8.3 AWS EC2 with Terraform](./module-08-terraform-provisioners/module-08.3-aws-ec2-with-terraform/README.md) | 📝 🧪 ☁️ [EC2, key pair, SG](./module-08-terraform-provisioners/module-08.3-aws-ec2-with-terraform/hands-on-lab/README.md) |
| [8.4 Terraform provisioners](./module-08-terraform-provisioners/module-08.4-terraform-provisioners/README.md) | 📝 🧪 ☁️ [Provisioners lab](./module-08-terraform-provisioners/module-08.4-terraform-provisioners/hands-on-lab/README.md) |
| [8.6 Considerations with provisioners](./module-08-terraform-provisioners/module-08.6-considerations-with-provisioners/README.md) | 📝 Why provisioners are a last resort |

## Module 09 — Import, Taint and Debugging

| Lesson | Contains |
|--------|----------|
| [9.1 Terraform taint](./module-09-terraform-import-tainting-and-debugging/module-09.1-terraform-taint/README.md) | 📝 taint and `-replace` |
| [9.2 Debugging](./module-09-terraform-import-tainting-and-debugging/module-09.2-debugging/README.md) | 📝 `TF_LOG`, `TF_LOG_PATH` |
| [9.3 Terraform import](./module-09-terraform-import-tainting-and-debugging/module-09.3-terraform-import/README.md) | 📝 Bringing existing resources into state |

## Module 10 — Terraform Modules

This is the class about the **real Terraform modules concept** (reusable code).

| Lesson | Contains |
|--------|----------|
| [10.1 What are modules](./module-10-terraform-modules/module-10.1-what-are-modules/README.md) | 📝 Root vs child, reusing modules for environments |
| [10.2 Creating and using a module](./module-10-terraform-modules/module-10.2-creating-and-using-a-module/README.md) | 📝 Payroll app module deployed in two regions |
| [10.3 Using modules from the Registry](./module-10-terraform-modules/module-10.3-using-modules-from-the-registry/README.md) | 📝 Registry security group module |

➡️ Full AWS practice: [nginx web app with reusable Terraform modules](./terraform-projects/terraform-modules-multi-env/README.md).

## Module 11 — Terraform Workspaces

| Lesson | Contains |
|--------|----------|
| [11 Terraform workspaces](./module-11-terraform-workspaces/README.md) | 📝 One code, separate state per environment |

---

## Projects

Standalone projects in [`terraform-projects/`](./terraform-projects/). These aren't tied to one class.

| Project | What I built |
|---------|--------------|
| [Conditional EC2 sizing](./terraform-projects/conditional-ec2-sizing/README.md) | ☁️ One resource block that creates `t2.micro` for dev and `t2.medium` for prod |
| [nginx web app with reusable modules](./terraform-projects/terraform-modules-multi-env/README.md) | ☁️ VPC, security group, IAM and EC2 **Terraform modules** joined by one `nginx-web-app` module, with an S3 backend, for dev, staging and production. Includes break-and-fix troubleshooting |

## Standalone notes

| Note | Contains |
|------|----------|
| [Lab Setup: Terraform + AWS](./lab-setup-terraform-aws/README.md) | 📝 🧪 ☁️ IAM user, access key, `aws configure`, authentication vs authorization, first EC2 + SG lab step by step |
| [Terraform core workflow](./core-workflow/terraform-core-workflow.md) | 📝 init → plan → apply |
| [Terraform CLI vs Terraform Cloud](./terraform-cli-vs-cloud.md) | 📝 Local CLI vs HCP Terraform |
| [AWS resource code](./aws-resource-code/README.md) | ☁️ Basic resource code, one file each: VPC, subnets, internet gateway, route table, security group, EC2, S3, IAM |
