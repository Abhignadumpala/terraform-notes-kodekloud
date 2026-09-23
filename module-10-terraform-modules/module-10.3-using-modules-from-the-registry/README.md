# 📘 Module 10.3: Using Modules from the Registry

> In this note, I learn how to use modules from the Terraform Registry to make infrastructure provisioning simpler. Terraform modules let me reuse and share configurations across projects. A local module lives on the same machine as Terraform, while modules from the Registry have the added benefit of being easy to share with the community.

---

## Local Module Example

A typical local module configuration looks like this:

```hcl
module "dev-webserver" {
  source = "../aws-instance/"
  key    = "webserver"
}
```

---

## Terraform Registry Modules

Modules in the [Terraform Registry](https://registry.terraform.io/browse/modules) are organized by the provider they support. They come in two categories:

- **Partner Modules:** Published by HashiCorp partners and reviewed by HashiCorp. These have a **Partner** badge, and I can use the Partner filter to show only these.
- **Community Modules:** Created by users. These are not reviewed by HashiCorp.

> 💡 No badge doesn't mean low quality. The popular `terraform-aws-modules` modules (like the security group module below) are community modules, but they're very widely used and actively maintained.

When I search for a module — say, to create AWS security groups — I see many options. Each module in the Registry shows details like the publisher, available versions, inputs, outputs, and usage instructions with examples.

Official docs: [Find and use modules in the Terraform Registry](https://developer.hashicorp.com/terraform/registry/modules/use).

---

## Referencing a Security Group Module

This example references the AWS security group module from the Terraform Registry:

```hcl
module "security-group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "6.0.0"
  # insert the module's inputs here
}
```

A Registry `source` has three parts: `<NAMESPACE>/<NAME>/<PROVIDER>` — here `terraform-aws-modules` / `security-group` / `aws`.

---

## Creating an SSH Security Group

A common use case is a security group that allows inbound SSH access. The module has a ready-made SSH sub-module, which takes three main inputs:

- The name of the security group.
- The VPC it will be created in.
- The CIDR blocks allowed to connect over SSH.

Below is the configuration for the SSH sub-module:

```hcl
module "security-group_ssh" {
  source  = "terraform-aws-modules/security-group/aws//modules/ssh"
  version = "6.0.0"
  vpc_id  = "vpc-0a1b2c3d4e5f67890"
  name    = "ssh-access"

  ingress_cidr_ipv4 = {
    office = "10.10.0.0/16"
  }
}
```

- The `//` in the `source` points to a folder inside the module — here, `modules/ssh`.
- `ingress_cidr_ipv4` is a map: each key is a name I pick (like `office`), and each value is a CIDR block allowed in.

> ⚠️ Version 6 of this module needs Terraform `>= 1.5.7` and the AWS provider `>= 6.29`. My labs pin `aws ~> 5.0`, so with those I'd pin this module to `~> 5.0` too — version 5 uses `ingress_cidr_blocks = ["10.10.0.0/16"]` (a list) instead of `ingress_cidr_ipv4`. The module's [Registry page](https://registry.terraform.io/modules/terraform-aws-modules/security-group/aws/latest/submodules/ssh) always shows the inputs for each version.

> 💡 I always pin the module version to keep things consistent and avoid surprise updates. If I leave out `version`, Terraform downloads the latest release, which can bring in changes that break my setup — like the input rename between versions 5 and 6 above.

---

## Initializing and Downloading Modules

To use a module from the Terraform Registry, I first initialize my configuration. `terraform init` downloads both the providers and the modules. If the provider plugins are already downloaded, I can fetch just the module with:

```bash
$ terraform get
Downloading registry.terraform.io/terraform-aws-modules/security-group/aws 6.0.0 for security-group_ssh...
- security-group_ssh in .terraform/modules/security-group_ssh/modules/ssh
- security-group_ssh.security_group in .terraform/modules/security-group_ssh
```

The second line is the SSH sub-module. The third line is the main security group module, which the SSH sub-module uses inside it.

After the download, I create the security group by running:

1. `terraform plan` – to view the changes.
2. `terraform apply` – to apply the configuration.

Official docs: [`terraform get`](https://developer.hashicorp.com/terraform/cli/commands/get) and [Module sources](https://developer.hashicorp.com/terraform/language/modules/sources).

---

## Summary

- ✅ Local modules use a folder path as `source`; Registry modules use `<NAMESPACE>/<NAME>/<PROVIDER>`
- ✅ Partner modules have a badge and are reviewed by HashiCorp; community modules are made by users
- ✅ `//` in a `source` points to a sub-module folder, like `//modules/ssh`
- ✅ `terraform init` downloads providers and modules; `terraform get` downloads only modules
- ⚠️ I always pin `version` — a new major version can rename inputs and break my code

---

## Key Takeaway

**Before writing a common piece of infrastructure from scratch, I check the Terraform Registry for a module, pin its version, and read its inputs for that version.**

- ✅ The Registry page shows the inputs, outputs, and examples for every version
- ⚠️ A module's own requirements (Terraform and provider versions) must match my project's

---

## Practice & Next Steps

Find the `terraform-aws-modules/security-group/aws` module in the Registry, open its `ssh` sub-module, and compare the inputs for version 5 and version 6. Then add the SSH sub-module to a lab folder, run `terraform get`, and check what gets downloaded into `.terraform/modules/`.

Learn more:

- [Terraform Modules](https://developer.hashicorp.com/terraform/language/modules)
- [Terraform Registry](https://registry.terraform.io/)
- [AWS Provider for Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

That closes out Module 10.
