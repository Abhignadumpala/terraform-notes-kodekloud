# 📘 Module 5.11: Locals

> Define a value once, in a `locals` block, and reference it everywhere with `local.<name>` — instead of retyping the same string or tag map in every resource.

---

## Introduction

I checked, and this repo has never actually used a `locals` block anywhere — every `local_file` match in earlier modules is a different thing entirely, a resource *type* for writing files, not this feature. That's the gap this note fills.

**A concrete example of the problem, from my own labs:** the [5.6 count lab](../module-05.6-count/hands-on-lab/count-code/ec2_instances.tf) and the [5.7 for_each lab](../module-05.7-for-each/hands-on-lab/for-each-code/ec2_instances.tf) both have a `tags` block that's almost identical — same `Name` pattern, same shape, differing only in one `Project` string (`"count-lab"` vs. `"for-each-lab"`). Two labs isn't enough to feel the pain yet, but that's exactly the kind of repeated shape `locals` exists to centralize once there are five labs, not two.

---

## What Locals Are

A `locals` block defines named expressions, evaluated once, referenced anywhere in that module with `local.<name>`:

```hcl
locals {
  app_name    = "my-app"
  environment = "dev"
}

# used elsewhere as local.app_name, local.environment
```

Unlike a `variable`, a local isn't something a caller sets from outside — it's always computed from an expression I write, inside the config itself. It can be a plain literal like above, or built from variables, data sources, or other locals.

---

## Grouping Locals, and Referencing Locals From Locals

I can write more than one `locals` block in the same module — this is just for grouping related values so they're easier to find, not a functional difference. And a local's expression can reference another local, as long as it doesn't create a cycle (local A depending on local B which depends back on A) — Terraform has no ordering of statements the way a regular script does, so a genuine circular reference between two locals is a real error, not just bad style.

```hcl
locals {
  app_team = "customer-experience"
}

locals {
  # Common tags for every resource in this config
  common_tags = {
    Name      = var.app_name
    Owner     = var.owner
    AppTeam   = local.app_team          # a local referencing another local
    CreatedBy = data.aws_caller_identity.current.account_id
  }
}
```

```hcl
resource "aws_instance" "web_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  tags          = local.common_tags
}
```

Every resource that sets `tags = local.common_tags` gets the exact same tag set — change the map once, and it changes everywhere it's used.

---

## Rewriting My Own Duplication With a Local

Going back to the `count`/`for_each` lab example from the introduction — here's what centralizing that repeated tag shape would actually look like, using [5.10](../module-05.10-built-in-functions/README.md)'s `format()`:

```hcl
locals {
  project_tags = {
    Name    = each.value            # still per-instance, so this can't move into the local itself
    Project = format("%s-lab", "for-each")
  }
}
```

Worth being honest about the limit here: `each.value` only exists inside a `resource` block using `for_each`, so it can't be baked into a `locals` block that gets reused across a `count`-based resource and a `for_each`-based one — a local is evaluated once for the whole module, not once per resource instance. What *can* move into a shared local is the part that's actually the same in both labs — the fixed keys and the `"...-lab"` naming pattern — while `Name` stays inline per resource. Locals centralize what's genuinely identical; they don't erase a real difference between two resources by pretending it isn't there.

---

## When to Use Locals

✅ **Naming conventions** — a shared prefix/suffix so every resource name follows the same pattern
✅ **Standard tag maps** — one `common_tags` map instead of retyping the same keys on every resource
✅ **Derived values** — combining a few variables/data sources into one meaningful name, computed once
✅ **Hiding a genuinely complex expression** behind a name that says what it's *for*

❌ **Don't** wrap an already-obvious value in a local just to have one — `local.instance_type = "t2.micro"` used exactly once adds a layer of indirection for no reason. The official docs make this same point directly: locals "can make configuration harder to read because they obscure where values originate" — worth remembering before reaching for one automatically.

---

## 📌 A Few Things I Couldn't Get a Clean Confirmation On

Checked the current Terraform docs while writing this. Confirmed directly: the guidance above about not overusing locals for obvious values is a real, quoted warning in the official docs, not something I'm inferring.

Less certain, based on established Terraform behavior rather than a docs quote I could pin down: multiple `locals` blocks per module being allowed, and a circular reference between two locals being a hard error. Both match everything else I know about how Terraform's dependency graph works, but I'm flagging them as "confident, not confirmed word-for-word" rather than overclaiming a verification I don't actually have.

---

## Summary

`locals` define a named expression once per module and let every resource, output, or other local reference it with `local.<name>` — the same "single source of truth" idea `variables` gives me for external input, but for values computed *inside* the config itself.

We covered:
- ✅ A `locals` block, and `local.<name>` to reference it
- ✅ Multiple `locals` blocks are fine — grouping, not a functional difference
- ✅ Locals can reference other locals, but not circularly
- ✅ Applied to my own repo's real duplication — the near-identical tag blocks in the 5.6/5.7 labs — and where that centralizing actually stops, since `each.value` can't live inside a module-wide local
- ✅ When *not* to use one — an obvious value used once doesn't need a name

---

## Key Takeaway

**`locals` = a value computed once inside the config, referenced everywhere with `local.<name>`.**

- ✅ Centralizes naming conventions, tag maps, and derived values
- ✅ Multiple `locals` blocks are just for grouping — no functional difference
- ✅ Can reference other locals, never circularly
- ⚠️ Only centralizes what's actually identical across resources — a per-instance value like `each.value` still can't move into a shared local

---

## Practice & Next Steps

Add a `locals` block to the [5.7 for_each lab](../module-05.7-for-each/hands-on-lab/for-each-code/) that centralizes the `Project = "for-each-lab"` tag into a `common_tags`-style map, apply it alongside the per-instance `Name` tag, and run `terraform plan` — it should show `0 to change`, confirming the local produces the exact same tag values as the literal it replaced.
