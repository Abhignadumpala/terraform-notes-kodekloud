# 📘 Module 5.9: The `terraform` Block

> The one block that configures Terraform itself instead of my infrastructure — CLI version, provider requirements, and where state lives, all in one place.

---

## Introduction

I've already written a `terraform { }` block in almost every lab in this repo — it's where `required_providers` lives ([Module 5.8](../module-05.8-version-constraints/README.md)), and it's where `backend "s3"` lives ([Module 4.1](../../module-04-terraform-state/module-04.1-purpose-of-state/README.md), [Module 4.2](../../module-04-terraform-state/module-04.2-terraform-state-considerations/README.md)). What I hadn't written down anywhere is the block itself — what it's *for*, as a whole, and the one piece I've never actually used yet: `required_version`.

**The practical point of this note:** in a real project, I don't write these three things in three separate places. They all go in **one `terraform { }` block** — usually its own file, `versions.tf`, sitting next to `main.tf` and `variables.tf`. That block is Terraform's equivalent of a settings menu for the *tool itself*: which CLI version is allowed to run this config, which providers it needs and at what versions, and where to store state. None of that is infrastructure — it's information about how Terraform itself should behave while it manages that infrastructure. That's the distinction that makes it worth its own note instead of just being a detail inside the provider or backend lessons.

---

## The Three Jobs of the `terraform` Block

```hcl
terraform {
  required_version = "~> 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.87.0"
    }
  }

  backend "s3" {
    bucket = "my-terraform-state-bucket"
    key    = "project/terraform.tfstate"
    region = "us-east-1"
  }
}
```

1. **`required_version`** — which Terraform CLI version(s) are allowed to run this config at all. *(New in this note — covered below.)*
2. **`required_providers`** — which providers this config needs, and which versions of them. Already covered in depth in [Module 5.8](../module-05.8-version-constraints/README.md) — same `~>`, `>=`, `!=` syntax, same AWS examples. Not repeating that here.
3. **`backend`** — where the state file actually lives (S3, in every lab in this repo). Already covered in [Module 4.1](../../module-04-terraform-state/module-04.1-purpose-of-state/README.md) and hands-on in [Module 4.2](../../module-04-terraform-state/module-04.2-terraform-state-considerations/README.md), including migrating to it and locking with `use_lockfile`. Not repeating that here either.

All three are just sibling settings inside the same block — there's no required order, and I can split them across multiple `.tf` files in the same folder if I want (Terraform merges every top-level `terraform { }` block it finds in a directory into one), but the common convention — and what I'll do from here on — is to keep all three together in a single `versions.tf`.

---

## `required_version` — Pinning the CLI Itself

This is the piece that's new here. `required_version` does for the **Terraform binary** what `required_providers`'s `version` field does for a provider — it's a version constraint, using the exact same syntax (`~>`, `>=`, `<=`, `!=`, exact pins). The difference is what it's constraining: not a plugin Terraform downloads, but the `terraform` command itself, wherever it's installed.

```hcl
terraform {
  required_version = "~> 1.10.0"
}
```

This says: only Terraform CLI versions `1.10.x` are allowed to run this configuration. Not `1.9.x`, not `1.11.0`.

**What happens if it doesn't match:** unlike a provider version mismatch (which `terraform init` can usually fix by downloading a different provider version), a CLI version mismatch can't be auto-fixed — the CLI you're running *is* the CLI you're running. So Terraform just refuses to proceed. Running any command against a config with a `required_version` your installed CLI doesn't satisfy fails immediately, with an error along these lines, before anything else runs:

```
Error: Unsupported Terraform Core version

This configuration does not support Terraform version 1.9.5. To proceed,
either choose another supported Terraform version or update the version
constraints. Version constraints are normally set for good reason, so
updating the constraints may lead to other errors or unexpected behavior.
```

That's the whole point of setting it: I'd rather see this error immediately than have `terraform plan` succeed on an incompatible CLI version and produce a plan that's subtly wrong because of a behavior change between CLI versions.

**Why this matters for a team, specifically:** the ["mismatched versions" scenario](https://developer.hashicorp.com/terraform/language/terraform) this concept comes from is exactly the `for_each`/`count` kind of problem, one level up — I tested my config against Terraform 1.10, a teammate has 1.5 installed, and without `required_version` there's nothing stopping them from running it anyway and hitting a behavior difference neither of us can easily debug. With it, they get a clear error the moment they try, instead of a confusing plan/apply failure.

---

## What I'd Actually Write

Putting it together, using this repo's own real backend example from the [4.2 lab](../../module-04-terraform-state/module-04.2-terraform-state-considerations/README.md) and the AWS provider constraint style from [5.8](../module-05.8-version-constraints/README.md):

```hcl
# versions.tf
terraform {
  required_version = "~> 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60.0"
    }
  }

  backend "s3" {
    bucket       = "my-terraform-state-bucket"
    key          = "project/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
```

One file, one block, three jobs — CLI version, provider version, and where state lives — all pinned down before a single resource is defined.

---

## 📌 Verified Against the Official Docs

- `required_version` uses the **same constraint syntax** as provider `version` fields (`~>`, `>=`, `<=`, `!=`, exact pins) — confirmed against the current Terraform docs.
- `required_version`, `required_providers`, and `backend` are documented as **sibling settings inside the same top-level `terraform { }` block** — this isn't just a convention, it's how the block is actually structured.
- One thing worth knowing if I ever look into Terraform Cloud/HCP Terraform later: `backend` and `cloud` are **mutually exclusive** — a config can use one or the other for state storage, never both at once.

---

## When to Use It

✅ **Always, in any shared or team project** — the whole point is preventing "works on my machine" drift between people or environments.

✅ **Even solo** — pinning `required_version` and provider versions means a config I write today still runs the same way in six months, after I've upgraded my own Terraform CLI in the meantime.

❌ **Skip `required_version` specifically** only for a genuine five-minute throwaway experiment where reproducibility doesn't matter at all — though at that point I'd question why I'm using Terraform instead of just clicking around the console.

---

## Summary

The `terraform { }` block configures Terraform itself, not my infrastructure — it's the one place that says which CLI version can run this config, which providers it needs, and where state is stored.

We covered:
- ✅ The three jobs of the block: `required_version`, `required_providers`, `backend`
- ✅ `required_version` — new here, same constraint syntax as provider versions, but pins the CLI binary itself instead of a plugin
- ✅ What happens on a mismatch: Terraform refuses to run at all, with a clear error, instead of proceeding on an untested CLI version
- ✅ In practice, all three live together in one block, conventionally its own `versions.tf` file
- ✅ Cross-linked rather than repeated: `required_providers` detail lives in [5.8](../module-05.8-version-constraints/README.md), `backend` detail lives in [4.1](../../module-04-terraform-state/module-04.1-purpose-of-state/README.md)/[4.2](../../module-04-terraform-state/module-04.2-terraform-state-considerations/README.md)

---

## Key Takeaway

**The `terraform` block = Terraform's own settings menu, not part of my infrastructure.**

- ✅ `required_version` pins the CLI itself — same `~>`/`>=` syntax as provider versions
- ✅ `required_providers` pins provider versions — see [5.8](../module-05.8-version-constraints/README.md)
- ✅ `backend` sets where state lives — see [4.1](../../module-04-terraform-state/module-04.1-purpose-of-state/README.md)/[4.2](../../module-04-terraform-state/module-04.2-terraform-state-considerations/README.md)
- ✅ All three are siblings in one block — conventionally a dedicated `versions.tf`
- ⚠️ A `required_version` mismatch isn't a warning — Terraform exits immediately without running anything

---

## Practice & Next Steps

Go back through this repo's existing `hands-on-lab/*/provider.tf` files (5.6, 5.7) and add a `required_version` constraint to each, pinned to whatever `terraform version` reports locally. Then try lowering the constraint below the installed version on purpose (e.g. `required_version = "~> 1.0.0"` against a much newer CLI) and run `terraform plan` — confirm it refuses to run, and read the actual error message it gives.
