# 📘 Module 5.6: Count

> Creating multiple identical resources from one block, and why removing an item from the list you're counting over is more dangerous than it looks

> 🧪 **Hands-on lab:** [Count](hands-on-lab/README.md) — deploy 3 EC2 instances from one `count` block, then remove one name from the list and watch the index-shifting pitfall happen for real.

---

## Introduction

This article explores Terraform's `count` meta-argument for creating multiple resource instances and discusses issues with modifying the underlying list used with `count`.

In this guide, we explore how the `count` meta-argument can be used to create multiple resource instances and discuss potential issues when modifying the underlying list used with `count`. This guide covers both static and dynamic count techniques to help you manage resources efficiently.

---

## What is Count Meta-Argument?

The `count` meta-argument is a Terraform feature that allows you to create multiple identical copies of a resource without writing the same resource block multiple times. (Briefly introduced in [Module 5.5](../module-05.5-meta-arguments/README.md).)

**How it works:**
- Add `count = N` to a resource block
- Terraform automatically creates N copies of that resource
- Each copy gets a unique index: `[0]`, `[1]`, `[2]`, ... `[N-1]`
- Use `count.index` to access the current copy's index

**Simple Example:**

```hcl
resource "aws_instance" "app" {
  count         = 3  # Creates 3 EC2 instances
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  tags = {
    Name = "instance-${count.index}"  # Names: instance-0, instance-1, instance-2
  }
}
```

**What Terraform creates:**
- `aws_instance.app[0]` → `instance-0`
- `aws_instance.app[1]` → `instance-1`
- `aws_instance.app[2]` → `instance-2`

**Key points:**
- ✅ No code repetition
- ✅ Trivial to scale — change `count = 3` to `count = 10`
- ✅ Every copy gets a unique index automatically
- ✅ Works on any resource type, not just `aws_instance`

---

## Understanding the Problem

### The Problem: Repetitive Code

Without `count`, three near-identical instances means three near-identical resource blocks:

```hcl
resource "aws_instance" "app" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  tags = { Name = "app-1" }
}

resource "aws_instance" "app2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  tags = { Name = "app-2" }
}

resource "aws_instance" "app3" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  tags = { Name = "app-3" }
}
```

**Problems:**
- ❌ Repetitive
- ❌ Hard to maintain — a config change means editing N blocks
- ❌ Doesn't scale to 10, 20, 100 instances

### The Solution: Use Count

```hcl
resource "aws_instance" "app" {
  count         = 3
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  tags = {
    Name = "app-${count.index}" # app-0, app-1, app-2
  }
}
```

**Benefits:**
- ✅ One block instead of three
- ✅ Scale by changing a single number
- ✅ Names generated automatically from the index

---

## Static vs. Dynamic Count

### Static Count

Just a hardcoded number:

```hcl
resource "aws_instance" "app" {
  count         = 3 # exactly 3, always
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  tags = {
    Name = "instance-${count.index}"
  }
}
```

### Dynamic Count with `length()`

Base the count on the size of a list instead:

```hcl
variable "instance_names" {
  default = ["web", "app", "db"]
}

resource "aws_instance" "servers" {
  count         = length(var.instance_names) # 3, from the list
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  tags = {
    Name = var.instance_names[count.index]
  }
}
```

`aws_instance.servers[0]` → `web`, `[1]` → `app`, `[2]` → `db`.

**What's `length()` doing here?** `length()` is a built-in Terraform function that counts the elements in a list (or the characters in a string, or the keys in a map). `length(var.instance_names)` on `["web", "app", "db"]` returns `3` — a plain number, which is exactly what `count` needs. So `count = length(var.instance_names)` reads as: *however many names are in this list, create that many instances.* Add a 4th name to the list and `length()` returns `4` on the next `plan` — `count` follows without you touching the resource block at all.

**Benefit:** change the list, and `count` follows automatically. ✅ ...but see the pitfall below — "change" doesn't mean "add and remove safely."

---

## Accessing Count Resources

```hcl
# All IDs, as a list
output "instance_ids" {
  value = aws_instance.web[*].id
}
# ["i-0123456789", "i-9876543210", "i-1111111111"]

# One specific instance
output "first_instance" {
  value = aws_instance.web[0].id
}
# "i-0123456789"

# The whole resource, all copies
output "all_instances" {
  value = aws_instance.web
}
```

---

## ⚠️ The Pitfall: Index Shifting

`count.index` is just a position in a list — `web[0]`, `web[1]`, `web[2]`. Terraform ties each resource instance to that *position*, not to the value that happened to be there when it was created. Remove an item from the front or middle of the list, and everything after it shifts down by one position — but Terraform doesn't see "one item removed," it sees "the values at these positions changed."

```hcl
resource "aws_instance" "web" {
  count         = length(var.web_server_names)
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  tags = {
    Name = var.web_server_names[count.index]
  }
}
```

**Before** (`web_server_names = ["web-1", "web-2", "web-3"]`): `web[0]=web-1`, `web[1]=web-2`, `web[2]=web-3`.

**After removing `"web-1"`** (`web_server_names = ["web-2", "web-3"]`): the list only has 2 elements now, but position 0 holds `"web-2"` and position 1 holds `"web-3"`.

```
# aws_instance.web[0] will be updated in-place
~ resource "aws_instance" "web" {
      id = "i-0123456789"
    ~ tags = {
        ~ "Name" = "web-1" -> "web-2"   # position 0's value changed
      }
  }

# aws_instance.web[1] will be updated in-place
~ resource "aws_instance" "web" {
      id = "i-9876543210"
    ~ tags = {
        ~ "Name" = "web-2" -> "web-3"   # position 1's value changed
      }
  }

# aws_instance.web[2] will be destroyed
- resource "aws_instance" "web" {
    - tags = {
        - "Name" = "web-3"
      } -> null                          # position 2 no longer exists — destroy it
  }
```

**Why:** `web[0]` is tied to position 0, and position 0's value changed from `"web-1"` to `"web-2"` — that's just a `Name` tag change, and `tags` isn't a ForceNew attribute, so Terraform updates it in place: same instance, new tag. Same story for `web[1]`. And `web[2]` — position 2 doesn't exist in the new list at all, so it's destroyed. Removing *one* name from the front of the list still ends up touching *every* resource after it — two instances silently relabeled plus one real deletion, instead of the one deletion you actually wanted. Here it's "only" a tag drifting quietly out of sync with what actually created the instance; if the position-shifted attribute *were* ForceNew (like `ami`), those same two resources would show `must be replaced` instead of updated in place — same root cause, more expensive outcome.

**The fix:** `for_each` (covered next, in Module 5.7) keys each resource by a stable *value* instead of a position, so removing one item only touches that one item. Until then, the rule with `count` over a list is: only ever append to the end, or accept that removing/reordering earlier elements will touch — update or replace, depending on the attribute — everything after them.

See the [hands-on lab](hands-on-lab/README.md) for this pitfall reproduced against real AWS instances.

---

## When to Use Count

✅ **Use `count` for:**
- Creating N identical resources (all same configuration)
- Simple scaling scenarios
- Static or predictable lists

❌ **Don't use `count` for:**
- Adding/removing items from lists (causes index shifting — silent in-place drift at best, unwanted replacements at worst)
- Named resources you reference often
- Complex configurations where you need readable names

**Better alternative:** Use `for_each` (Module 5.7) when list order matters or when you add/remove items

---

## Summary

In this guide, we demonstrated how to use the `count` meta-argument in Terraform to create multiple resource instances.

We examined:
- ✅ **Static count:** `count = 3` to create a fixed number of identical resources
- ✅ **Dynamic count:** `count = length(var.list)` to create based on list size
- ✅ **Accessing resources:** Using `count.index`, `[*]`, and individual indices
- ✅ **Common pitfall:** Removing elements from count lists causes index shifting — every resource after the removed item gets touched, whether that's a quiet in-place update or a full replacement

The most important lesson: **When using count with lists, be extremely careful about removing or reordering elements**, as this triggers index shifting — unnecessary changes across every resource after the removed item, ranging from a silently mislabeled tag to a full replacement.

---

## Key Takeaway

**`count` = Simple way to create N identical resources**

- ✅ Use `count = 3` for static count
- ✅ Use `count = length(var.list)` for dynamic count
- ✅ Use `count.index` to access current iteration
- ✅ Use `[*]` to access all instances
- ❌ Avoid removing items from count lists (causes index shifting — in-place drift or replacements)

---

## Practice & Next Steps

Practice using the `count` meta-argument in your Terraform projects to automate resource creation and better manage infrastructure changes.

**Important:** Always remember that count indices are fragile when list order changes — the actual damage (silent tag drift vs. a real replacement) depends on which attribute is keyed by `count.index`.

**Better alternative:** Use `for_each` (Module 5.7) when you need to add/remove items without replacing everything.
