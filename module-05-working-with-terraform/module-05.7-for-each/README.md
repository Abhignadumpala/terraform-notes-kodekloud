# 📘 Module 5.7: for_each

> Keying resources by a stable value instead of a position, so adding or removing one item only touches that one item — the fix for the [count pitfall](../module-05.6-count/README.md#️-the-pitfall-index-shifting) from Module 5.6.

---

## Introduction

Module 5.6 showed the problem: `count` ties every resource to a numbered slot (`web[0]`, `web[1]`, `web[2]`), not to the value that was in that slot when it was created. Remove or reorder an item, and everything after it shifts — Terraform can't tell "one thing was removed" from "several things changed."

`for_each` fixes that by keying each resource with the *value itself* — a name, a filename, an ARN — instead of a number. Remove that one key, and only that one resource is affected. Nothing else shifts, because nothing else's key changed.

---

## What is the `for_each` Meta-Argument?

Like `count`, `for_each` creates multiple instances of a resource from one block. The difference is what it uses as the resource's identity:

- `count` → identity is a **number** (`0`, `1`, `2`...), assigned by position in a list
- `for_each` → identity is a **key** (a string, or a map key) that you control

**How it works:**
- Add `for_each = <map or set>` to a resource block
- Terraform creates one instance per key
- Inside the block, `each.key` and `each.value` refer to the current item
- Reference a specific instance as `aws_instance.web["web-prod-1"]` — by key, not by number

---

## Trying It With a List (and Why It Fails)

The natural first move, coming from `count`, is to just swap `count` for `for_each` and point it at the same list:

```hcl
variable "web_server_names" {
  default = ["web-prod-1", "web-prod-2", "web-prod-3"]
}

resource "aws_instance" "web" {
  for_each      = var.web_server_names
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  tags = {
    Name = each.value
  }
}
```

`terraform plan` refuses to run:

```
Error: Invalid for_each argument

  on ec2_instances.tf line 6, in resource "aws_instance" "web":
   6:   for_each = var.web_server_names

The given "for_each" argument value is unsuitable: the "for_each"
argument must be a map, or set of strings, and you have provided a
value of type list of string.
```

**`for_each` only accepts a map, or a set of strings — never a plain list.** A list can have duplicates and a meaningful order; `for_each` needs something where every key is unique and unordered, so it can tell keys apart reliably. That's exactly what a map or a set gives it. (Confirmed still true against the current Terraform docs — this hasn't changed.)

---

## Fixing It: Two Ways

**Option 1 — convert the list to a set with `toset()`, right in the resource block:**

```hcl
variable "web_server_names" {
  type    = list(string)
  default = ["web-prod-1", "web-prod-2", "web-prod-3"]
}

resource "aws_instance" "web" {
  for_each      = toset(var.web_server_names)
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  tags = {
    Name = each.value
  }
}
```

**Option 2 — change the variable's type to a set of strings from the start:**

```hcl
variable "web_server_names" {
  type    = set(string)
  default = ["web-prod-1", "web-prod-2", "web-prod-3"]
}

resource "aws_instance" "web" {
  for_each      = var.web_server_names
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  tags = {
    Name = each.value
  }
}
```

Either way, `terraform plan` now works, and each instance is keyed by its own name instead of a number:

```
Terraform will perform the following actions:

  # aws_instance.web["web-prod-1"] will be created
  # aws_instance.web["web-prod-2"] will be created
  # aws_instance.web["web-prod-3"] will be created

Plan: 3 to add, 0 to change, 0 to destroy.
```

**Note on sets:** a set can't hold duplicate values (unlike a list). If two entries in `web_server_names` were identical, `toset()` would silently collapse them down to one — worth knowing before leaning on this for something where duplicates could realistically show up.

---

## Removing an Element — No More Index Shifting

This is the whole point. Remove `"web-prod-1"` from the list:

```hcl
variable "web_server_names" {
  type    = set(string)
  default = ["web-prod-2", "web-prod-3"]
}
```

```
Terraform will perform the following actions:

  # aws_instance.web["web-prod-1"] will be destroyed

Plan: 0 to add, 0 to change, 1 to destroy.
```

That's it. `aws_instance.web["web-prod-2"]` and `aws_instance.web["web-prod-3"]` don't even appear in the plan — their keys never changed, so Terraform leaves them completely alone. Compare that to [Module 5.6's `count` pitfall](../module-05.6-count/README.md#️-the-pitfall-index-shifting), where removing the same element caused 2 in-place updates plus a destroy — and the instance actually destroyed wasn't even the one that got "removed" from the list.

---

## Accessing and Outputting `for_each` Resources

Resources created with `for_each` are stored as a **map keyed by `each.key`**, not a list — so `[*]` and numeric indices don't apply here.

```hcl
output "web_server_ids" {
  value = { for name, inst in aws_instance.web : name => inst.id }
}

output "one_server" {
  value = aws_instance.web["web-prod-2"].id
}

output "all_servers" {
  value = aws_instance.web
}
```

```
web_server_ids = {
  "web-prod-2" = "i-0a1b2c3d4e5f6g7h8"
  "web-prod-3" = "i-1a2b3c4d5e6f7g8h9"
}
```

Each key in the output is the actual server name — `web-prod-2`, not `1`. That readability is a side effect of the same thing that fixes the pitfall: identity comes from the value, not the position.

---

## 📌 What's Changed Since This Was Written: the `moved` Block

If you already have infrastructure running under `count` (like the Module 5.6 lab) and switch that same resource block to `for_each`, Terraform doesn't see "the same 3 servers, just addressed differently." It sees `aws_instance.web[0]` disappear and `aws_instance.web["web-prod-1"]` appear as a brand-new resource — the *address* changed, even though nothing about the actual infrastructure needs to. Left alone, `terraform plan` would destroy all 3 running instances and recreate all 3 under the new addresses.

Terraform 1.1 added the **`moved` block** to solve exactly this: it tells Terraform "this old address and this new address are the same resource," so it updates the state file instead of destroying and recreating.

```hcl
moved {
  from = aws_instance.web[0]
  to   = aws_instance.web["web-prod-1"]
}
moved {
  from = aws_instance.web[1]
  to   = aws_instance.web["web-prod-2"]
}
moved {
  from = aws_instance.web[2]
  to   = aws_instance.web["web-prod-3"]
}
```

Run `terraform plan` with these in place alongside the new `for_each` block, and it reports `0 to add, 0 to change, 0 to destroy` — same instances, just renamed in state. The `moved` blocks can be deleted once every environment has applied the change at least once.

**Worth knowing:** if you're writing a *brand-new* resource with `for_each` — nothing deployed yet under `count` — none of this applies. `moved` blocks only matter when migrating existing, already-applied infrastructure between the two.

---

## `count` vs `for_each`

| | `count` | `for_each` |
|---|---|---|
| Identity | Position (`0`, `1`, `2`...) | Key (string, or map key) |
| Input type | Number, or `length()` of anything | Map, or set of strings |
| Reference a specific instance | `aws_instance.web[0]` | `aws_instance.web["web-prod-1"]` |
| Remove one item from the front/middle | Shifts every later instance's index — silent tag drift or unwanted replacements | Only the removed key's instance is touched |
| Best for | A fixed number of identical, interchangeable things | Named things you'll add, remove, or reference individually |
| Migrating existing infra between the two | — | Needs `moved` blocks (Terraform 1.1+), or it destroys and recreates everything |

---

## When to Use `for_each`

✅ **Use `for_each` for:**
- Resources you'll add or remove from over time
- Resources you reference individually and want readable addresses for
- Anything keyed naturally by a name, ARN, or other unique string

❌ **Don't bother with `for_each` for:**
- A truly fixed number of identical, interchangeable resources you'll never need to remove one of individually — `count` is simpler there

---

## Summary

`for_each` creates one resource instance per entry in a map or set, keyed by the entry itself instead of its position. That one difference is what makes it safe to add or remove items — a removed key only destroys the one resource tied to it, and every other instance keeps its own identity untouched.

We covered:
- ✅ Why `for_each` needs a **map or set of strings**, not a list — a plain list raises `Invalid for_each argument`
- ✅ Two ways to satisfy that: `toset()` in the resource block, or typing the variable as `set(string)` directly
- ✅ `each.key` / `each.value` inside the resource, and referencing instances by key (`aws_instance.web["name"]`)
- ✅ Removing an item destroys only that item — no shifting, no collateral changes
- ✅ Outputs built from `for_each` resources are maps, not lists — no `[*]`
- ✅ The `moved` block, for migrating already-deployed `count` resources to `for_each` without destroying them

---

## Key Takeaway

**`for_each` = create resources keyed by value, not position — the fix for `count`'s index-shifting pitfall**

- ✅ Accepts a map or a set of strings only — use `toset()` or a `set(string)` variable for a list of names
- ✅ Access the current item with `each.key` / `each.value`
- ✅ Reference an instance by its key: `aws_instance.web["name"]`
- ✅ Removing one key only ever touches that one resource
- ⚠️ Migrating *existing* `count` infrastructure to `for_each`? Use `moved` blocks, or Terraform will destroy and recreate everything

---

## Practice & Next Steps

Take the Module 5.6 lab and convert it: change `web_server_names` to a `set(string)`, swap `count` for `for_each`, and update the tags and outputs to use `each.value`. Remove a name from the *middle* of the set this time, and confirm only that one instance shows up in the plan — nothing else shifts.

Hands-on lab for this module to follow, reproducing the above against real AWS instances the same way Module 5.6's did.
