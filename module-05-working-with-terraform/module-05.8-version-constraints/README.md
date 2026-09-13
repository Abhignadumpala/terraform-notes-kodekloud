# 📘 Module 5.8: Version Constraints

> Pinning which provider version Terraform is allowed to install, so `terraform init` doesn't silently grab a newer release that breaks my config.

---

## Introduction

Every lab so far has had a `required_providers` block with `source = "hashicorp/aws"` and some `version` string. I never explained what that string actually does — this module is that explanation.

By default, `terraform init` downloads the **latest** provider version available on the public Terraform Registry. That's fine right up until a provider ships a breaking change and my next `terraform init` on a fresh machine (or a teammate's) quietly pulls in a version I never tested against. Version constraints are how I tell Terraform "only ever install a version that fits this range" instead of "always get the newest."

---

## The Problem: `terraform init` Grabs the Latest Version by Default

A config with no version pinned at all:

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  tags = {
    Name = "web-prod-1"
  }
}
```

Running `terraform init` against this looks something like:

```
Initializing the backend...

Initializing provider plugins...
- Finding latest version of hashicorp/aws...
- Installing hashicorp/aws v6.15.0...
- Installed hashicorp/aws v6.15.0 (signed by HashiCorp)

The following providers do not have any version constraints in configuration,
so the latest version was installed.

To prevent automatic upgrades to new major versions that may contain breaking
changes, we recommend adding version constraints in a required_providers block
in your configuration, with the constraint strings suggested below.

* hashicorp/aws: version = "~> 6.15.0"

Terraform has been successfully initialized!
```

Terraform even tells you, right in the output, that you should be pinning a version and suggests a constraint string. That warning is worth reading — it's not boilerplate.

> 💡 **Always specify provider versions.** A provider major-version bump can rename resource arguments, change default behavior, or drop attributes outright — none of which shows up until `terraform plan` starts producing errors or unexpected diffs on a config that used to work fine.

---

## Pinning a Specific Version

Add a `terraform` block with `required_providers`, and give the provider an exact `version`:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.60.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  tags = {
    Name = "web-prod-1"
  }
}
```

`terraform init` now installs exactly `5.60.0` — not whatever happens to be newest that day. This is the exact move I ended up making in my own [5.7 `for_each` lab](../module-05.7-for-each/hands-on-lab/for-each-code/provider.tf): it started out as `version = "~> 5.0"`, and I later pinned it down to `version = "5.60.0"` after that range had already carried me from provider `5.60.0` up through `5.100.0` between lab runs — an exact pin was the simplest way to stop worrying about which one `init` would pick next.

---

## Comparison Operators

Terraform's version strings aren't limited to a single exact version. It supports the usual comparison operators:

| Operator | Meaning |
|---|---|
| `=` (or nothing) | Exactly this version |
| `!=` | Any version except this one |
| `>`, `>=` | Greater than / at least |
| `<`, `<=` | Less than / at most |

**Excluding a specific version** — say, a `hashicorp/aws` release that shipped a known-bad regression:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "!= 5.70.0"
    }
  }
}
```

**Combining operators into a range** — anything newer than `5.50.0` but older than `6.0.0`, while still excluding one specific bad release in between:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "> 5.50.0, < 6.0.0, != 5.70.0"
    }
  }
}
```

Terraform picks the **highest version that satisfies every condition** in the list — so with the constraint above, it'd land on the newest `5.x` release below `6.0.0` that isn't `5.70.0`.

---

## The Pessimistic Constraint Operator (`~>`)

Typing `> 5.0.0, < 6.0.0` by hand every time gets old fast. And "let small updates through, but block anything that might break my config" is such a common thing to want that Terraform gives it its own shortcut: `~>`.

It's officially called the "pessimistic constraint operator," but ignore the fancy name — all it means is *"be cautious. Assume a bigger version bump might break something, so only auto-update the small stuff."*

**The simple rule: count how many numbers you typed after `~>`. Terraform locks all of them except the very last one — only that last number is allowed to go up.**

**Example with two numbers — `~> 5.60`:**

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}
```

I typed two numbers (`5` and `60`), so the `5` is locked and only the `60` can move. That means Terraform can install `5.60`, `5.61`, all the way up to `5.99` — but the second it would need `6.0`, it stops. Same as writing `>= 5.60.0, < 6.0.0`, just shorter.

**Example with three numbers — `~> 5.60.0`:**

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60.0"
    }
  }
}
```

Now I typed three numbers, so the first two (`5` and `60`) are locked, and only the last one (`0`) can move. Terraform can install `5.60.0`, `5.60.1`, up to `5.60.99` — but not `5.61.0`. Adding that third number tightened the range a lot. Same as writing `>= 5.60.0, < 5.61.0`.

So the more numbers I write after `~>`, the tighter the range gets — because I'm locking one more digit in place each time.

Running `terraform init` with that three-number version:

```
Initializing the backend...

Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.60.0"...
- Installing hashicorp/aws v5.60.0...
- Installed hashicorp/aws v5.60.0 (signed by HashiCorp)

Terraform has been successfully initialized!
```

**Checked this against the current Terraform docs and it still holds** — `~>` only ever lets the last number move, everything before it is locked. HashiCorp's own advice, in plain terms: if you're writing a reusable piece of Terraform code that other people's projects will plug in (a "module"), just set a minimum version and don't cap it, so you're not the reason someone can't use a newer provider. But for an actual project you run yourself — like every `.tf` file in this repo's `hands-on-lab/` folders — use `~>` so you still get small bugfixes automatically, without ever getting hit by a big breaking change you didn't see coming.

---

## 📌 What's Changed Since This Was Written: the Dependency Lock File

The KodeKloud lesson this note is based on stops at `version` constraints in `required_providers`. What it doesn't mention — because dependency locking existed but wasn't emphasized the same way yet — is the **`.terraform.lock.hcl`** file that `terraform init` generates in the same directory.

Here's the distinction that actually matters: `version` in `required_providers` defines a *range* of acceptable versions. The lock file records the *one exact version* Terraform actually picked from that range, plus a fingerprint of the downloaded provider file so Terraform can tell if it ever changes unexpectedly. That way, every future `init` — on my machine, a teammate's, or a CI server — reuses that exact version instead of silently drifting to a newer one that also happens to satisfy the constraint.

I've seen this directly in this repo's own lab runs. Every `terraform init` in the [5.6](../module-05.6-count/hands-on-lab/README.md) and [5.7](../module-05.7-for-each/hands-on-lab/README.md) labs prints:

```
Initializing provider plugins...
- Reusing previous version of hashicorp/aws from the dependency lock file
- Using previously-installed hashicorp/aws v5.60.0
```

That's the lock file doing its job — even though `~> 5.0` would technically also permit `5.100.0`, `init` didn't reach for it, because `5.60.0` was already recorded as the selected version.

**Practical takeaway:**
- `version` constraint → the *range* I'm willing to accept
- `.terraform.lock.hcl` → the *exact* version actually in use, committed to version control so everyone gets the same one
- To deliberately move to a newer version within the constraint, run `terraform init -upgrade` — this re-evaluates the constraint and updates the lock file on purpose, rather than it happening as a side effect of a random `init`

Every `hands-on-lab/*/` folder in this repo tracks its `.terraform.lock.hcl` in git for exactly this reason.

---

## When to Use Which Constraint

✅ **Exact version (`= "5.60.0"`)** — when I want zero surprises, especially in a lab I'm actively debugging and don't want the provider version itself to be a variable.

✅ **Pessimistic, three-part (`~> 5.60.0`)** — patch releases only. Good default for anything I want to stay put but still pick up bugfixes for.

✅ **Pessimistic, two-part (`~> 5.60`)** — minor and patch releases, no major bumps. HashiCorp's suggested default for a project you run yourself.

✅ **Floor only (`>= 5.0.0`)** — good for a reusable module (a chunk of Terraform code other people's projects plug in), not for a project you're actually deploying.

❌ **No constraint at all** — fine for a five-minute throwaway experiment, risky for anything meant to still `apply` cleanly next month.

---

## Summary

Version constraints in `required_providers` control which provider versions Terraform is allowed to install — without one, `terraform init` always reaches for the latest, which can break a config that worked fine yesterday.

We covered:
- ✅ Why unconstrained `init` is risky — it always grabs latest, silently
- ✅ Pinning an exact version with `version = "5.60.0"`
- ✅ Comparison operators (`=`, `!=`, `>`, `>=`, `<`, `<=`) and combining them into a range
- ✅ The pessimistic operator `~>` — two-part vs three-part behavior
- ✅ The `.terraform.lock.hcl` dependency lock file — what actually pins the *exact* version used across runs, on top of whatever range `version` allows

---

## Key Takeaway

**Version constraints = the range of provider versions `terraform init` is allowed to pick from.**

- ✅ No constraint → always installs latest, which can break silently
- ✅ Exact pin (`"5.60.0"`) → zero surprises, but manual work to ever upgrade
- ✅ `~> 5.60.0` → patch updates only; `~> 5.60` → minor + patch, no major bumps
- ⚠️ The constraint sets the *range* — the committed `.terraform.lock.hcl` is what actually pins the *exact* version everyone gets

---

## Practice & Next Steps

Go back through [5.6](../module-05.6-count/hands-on-lab/for-each-code) and [5.7](../module-05.7-for-each/hands-on-lab/for-each-code)'s `provider.tf` files and try each constraint style — `~> 5.0`, `~> 5.60`, `~> 5.60.0`, and an exact pin — against the current AWS provider release, and watch what `terraform init` picks each time. Then check `.terraform.lock.hcl` before and after to see exactly what it recorded.
