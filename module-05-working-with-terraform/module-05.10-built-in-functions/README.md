# 📘 Module 5.10: Built-In Functions

> A compact set of functions Terraform ships with, for computing values instead of hard-coding them — names, sizes, subnet math, and converting between list/set/map so the right type reaches `for_each`.

---

## Introduction

Every function I've used so far in this repo showed up as a side detail inside some other lesson — `toset()` to satisfy `for_each`'s type requirement in [5.7](../module-05.7-for-each/README.md), `length()` to drive `count` in [5.6](../module-05.6-count/README.md). This note is the other way around: the functions themselves, as their own topic.

**The pattern is always the same:** `function_name(arg1, arg2, ...)`. No parentheses-free shorthand, no methods on objects like `x.upper()` — every function is a plain call, and it can go anywhere Terraform expects a value: inside a resource argument, a `local`, an `output`, a string interpolation. HCL doesn't let me *write* my own functions — I only ever call the ones Terraform ships with.

I'm grouping them the same way this topic is usually taught: numeric, string, network, and type conversion.

---

## Numeric Functions

For computing sizes, counts, and limits instead of typing a number and hoping it's still right later.

- `max(...)` — the largest of the given numbers
- `min(...)` — the smallest
- `floor(x)` — round down to the nearest whole number
- `ceil(x)` — round up

```hcl
variable "requested_capacity" {
  type    = number
  default = 15
}

locals {
  # Never provision fewer than 3, no matter what gets requested
  instance_count = max(3, var.requested_capacity)
}
```

`max(3, var.requested_capacity)` reads as "whichever is bigger" — so if someone sets `requested_capacity` to `1`, I still get `3`. That's a floor I can rely on without an `if`.

---

## String Functions

For building names and tags that follow a convention, instead of typing `"web-prod-1"` by hand in five different places (which is exactly what every lab in this repo up to Module 5.5 did — plain string literals).

- `join(separator, list)` — glue a list of strings together
- `format(spec, ...)` — `printf`-style templated string
- `upper(s)` / `lower(s)` — case conversion
- `replace(s, old, new)` — substring substitution
- `base64encode(s)` — encode a string, typically for `user_data`

```hcl
variable "environment" { default = "prod" }
variable "role"        { default = "web" }

locals {
  # "prod-web-1", "prod-web-2", "prod-web-3" - built, not typed
  server_name = format("%s-%s", var.environment, var.role)
}

resource "aws_instance" "web" {
  for_each      = toset(["1", "2", "3"])
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  tags = {
    Name = "${local.server_name}-${each.value}"
  }
}
```

`join("-", [var.environment, var.role])` would produce the same `"prod-web"` string as `format("%s-%s", var.environment, var.role)` here — `join` is for gluing an existing list together, `format` is for building a string from separate pieces with a template. Either works for this; `format` reads more clearly once there are more than two or three pieces.

---

## Network Functions — `cidrsubnet`

For splitting a VPC's address block into subnets by math instead of typing out CIDR ranges and hoping they don't overlap.

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  availability_zone = "us-east-1a"
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 3, 0)  # 10.0.0.0/19
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  availability_zone = "us-east-1b"
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 3, 1)  # 10.0.32.0/19
}
```

`cidrsubnet(prefix, newbits, netnum)`, verified against the current Terraform docs:

- **`prefix`** — the starting block, `10.0.0.0/16` here
- **`newbits`** — how many extra bits to carve off the prefix. `/16` plus `newbits = 3` gives `/19` subnets, and splits the block into `2^3 = 8` possible subnets
- **`netnum`** — which one of those subnets to return, `0`-indexed. Valid range is `0` through `2^newbits - 1` — so `0` through `7` here

`netnum = 0` and `netnum = 1` are just "the first `/19`" and "the second `/19`" out of the 8 available inside `10.0.0.0/16`. Same function works for IPv6 blocks too, keeping whichever address family the input `prefix` was.

> ⚠️ **Worth being careful with:** if `netnum` is computed dynamically (from a list index, say) instead of a literal like `0`/`1`, make sure it can never reach or exceed `2^newbits`. Terraform will happily compute a `netnum` that's out of range into something that silently overlaps another subnet, instead of erroring — I haven't hit this myself yet, but it's exactly the kind of bug that only shows up once two subnets fight over the same addresses.

---

## Type Conversion Functions

For getting a value into the exact collection type something else needs — most often, `for_each`.

- `toset(x)` — convert to a set (drops duplicates, unordered)
- `tolist(x)` — convert to a list (keeps order, allows duplicates, supports indexing)
- `tomap(x)` — convert to a map
- `tostring(x)` — convert to a plain string

This is the same move as [5.7](../module-05.7-for-each/README.md#trying-it-with-a-list-and-why-it-fails): `for_each` only accepts a map or a set of strings, so a `list(string)` variable has to pass through `toset()` first. The new piece here is what happens if I need a *stable index* back out of that set — sets don't have positions, so `index()` can't work on one directly:

```hcl
variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1a", "us-east-1b"]  # note the duplicate
}

locals {
  unique_zones = toset(var.availability_zones)  # duplicate dropped, per 5.7's note on toset()
}

resource "aws_subnet" "example" {
  for_each = local.unique_zones

  vpc_id            = aws_vpc.main.id
  availability_zone = each.value
  cidr_block = cidrsubnet(
    aws_vpc.main.cidr_block,
    2,
    index(tolist(local.unique_zones), each.value)  # tolist() first - index() needs a list, not a set
  )
}
```

`tolist(local.unique_zones)` converts the set back to a list just long enough for `index()` to find `each.value`'s position in it. Skipping the `tolist()` and calling `index()` straight on a set doesn't work — `index()` needs something ordered to return a position from.

---

## Quick Reference

| Function | Category | Returns | Typical use |
|---|---|---|---|
| `max(...)` / `min(...)` | Numeric | number | Enforce a floor/ceiling on a computed value |
| `floor(x)` / `ceil(x)` | Numeric | number | Round a computed size or count |
| `join(sep, list)` | String | string | Glue an existing list into one string |
| `format(spec, ...)` | String | string | Build a string from separate pieces, printf-style |
| `upper(s)` / `lower(s)` | String | string | Enforce naming-convention casing |
| `replace(s, old, new)` | String | string | Substring substitution |
| `base64encode(s)` | String | string | Encode for `user_data` or an API payload |
| `cidrsubnet(prefix, newbits, netnum)` | Network | string (CIDR) | Split a VPC block into subnets by math |
| `toset(x)` | Type conversion | set | Satisfy `for_each`'s type requirement, drop duplicates |
| `tolist(x)` | Type conversion | list | Get back a stable, indexable order (e.g. before `index()`) |
| `tomap(x)` / `tostring(x)` | Type conversion | map / string | Reshape a value for a lookup or a tag |

---

## Summary

Terraform's built-in functions replace hard-coded strings and numbers with computed ones — same `function_name(args)` call pattern everywhere, no user-defined functions, just a fixed library to call into.

We covered:
- ✅ Numeric functions (`max`, `min`, `floor`, `ceil`) for computed sizing instead of typed-in numbers
- ✅ String functions (`join`, `format`, `upper`/`lower`, `replace`, `base64encode`) for consistent naming and payloads
- ✅ `cidrsubnet(prefix, newbits, netnum)` for splitting a VPC block into subnets by math — verified `newbits`/`netnum` behavior against the official docs
- ✅ Type conversion (`toset`, `tolist`, `tomap`, `tostring`) — the same `toset()` move from [5.7](../module-05.7-for-each/README.md), plus converting back to a list when `index()` needs an actual position

---

## Key Takeaway

**Functions replace hard-coded values with computed ones — same call pattern everywhere, no custom functions of my own.**

- ✅ `max`/`min`/`floor`/`ceil` for numbers, `join`/`format`/`replace` for strings
- ✅ `cidrsubnet(prefix, newbits, netnum)` — `newbits` sets how many subnets exist (`2^newbits`), `netnum` picks which one
- ✅ `toset()` for `for_each`, `tolist()` to get an indexable order back when I need one
- ⚠️ A dynamically computed `netnum` that reaches `2^newbits` silently produces an overlapping subnet instead of an error

---

## Practice & Next Steps

Take the `aws_vpc`/`aws_subnet` example above and extend it to 4 subnets instead of 2, using `cidrsubnet` with `netnum` values `0` through `3` and `newbits` adjusted so all 4 fit inside the same `/16`. Then take any resource name in an existing lab in this repo (`"web-prod-1"`, etc.) and rebuild it with `format()` from separate `var.environment`/`var.role`/`var.index` pieces instead of a literal string.
