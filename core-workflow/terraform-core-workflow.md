# Terraform Core Workflow — init → plan → apply

**Course:** KodeKloud — Terraform
**Related to:** Class 3 — Why Terraform

---

## 🔄 Terraform's Core Workflow

The basic Terraform workflow consists of three phases:

`terraform init` → `terraform plan` → `terraform apply`

---

## 🔹 Init — Initialize the Terraform Working Directory

When I run:

```
terraform init
```

Terraform prepares the working directory for use.

It:

→ Reads the configuration and identifies the required providers
→ Downloads the required provider plugins
→ Stores the downloaded providers inside the `.terraform` directory
→ Creates or updates `.terraform.lock.hcl`, which records the selected provider versions and their checksums

For example, if I'm using the AWS provider, Terraform downloads the appropriate AWS provider plugin into the `.terraform` directory.

📁 A simplified project structure can look like:

```text
terraform-project/
│
├── main.tf
├── variables.tf
├── outputs.tf
├── .terraform/
│   └── providers/
│       └── registry.terraform.io/
│           └── hashicorp/
│               └── aws/
│
└── .terraform.lock.hcl
```

The `.terraform` directory contains Terraform's local working data and downloaded provider plugins.

The `.terraform.lock.hcl` file is different — it records the provider versions and checksums Terraform selected, helping ensure consistent provider versions across environments.

---

## 🔹 Plan — Preview the Changes

When I run:

```
terraform plan
```

Terraform compares the desired configuration, the current state, and the real infrastructure to determine what changes are required.

It shows what Terraform intends to:

➕ Create
🔄 Modify
➖ Destroy

Nothing is changed in the infrastructure during `plan`.

---

## 🔹 Apply — Make the Changes

When I run:

```
terraform apply
```

Terraform executes the changes shown in the plan and updates the real infrastructure so that it matches the desired configuration.

---

## Overall Flow

```
Configuration (.tf)
        ⬇️
terraform init   → Prepare & download providers
        ⬇️
terraform plan   → Preview changes
        ⬇️
terraform apply  → Create/update infrastructure
```

---

**Back to why terraform :** https://github.com/Abhignadumpala/terraform-notes-kodekloud/blob/main/module-01-introduction-to-infrastructure-as-code/module-01.3-why-terraform/why-terraform.md
