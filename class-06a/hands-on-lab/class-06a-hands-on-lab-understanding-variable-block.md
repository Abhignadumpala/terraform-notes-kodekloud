# Class 6 Hands-On Lab: Variable Types in Practice

This lab covers three real-world scenarios with variables: using lists with different positions, sets with duplicate values, and type mismatches. The key learning is that **Terraform is forgiving — it silently fixes errors instead of rejecting them**.

## Lab 1: List Variables and Accessing Different Positions

### Setup

Created two files in `~/terraform-local-file/variables`:

**variable.tf:**
```hcl
variable "prefix" {
  default = ["Mr", "Mrs", "Sir"]
  type    = list
}
```

**main.tf (first version):**
```hcl
resource "random_pet" "my-pet" {
  prefix = var.prefix[0]
}
```

<img width="570" height="200" alt="variable.tf with list of three prefixes" src="images/01-list-variable.png" />

<img width="570" height="180" alt="main.tf using var.prefix[0]" src="images/02-main-with-prefix-0.png" />

### Initial Apply

Running `terraform apply` with `var.prefix[0]` (pointing to "Mr"):

```bash
terraform show
```

<img width="720" height="240" alt="terraform show output: random_pet created with Mr prefix, id=Mr-delicate-quetzal" src="images/04-terraform-show-first.png" />

Resource created: **`Mr-delicate-quetzal`** — using position 0 ("Mr") from the list.

### Changing Which Position is Accessed

Edited `main.tf` to access a different position:

**main.tf (second version):**
```hcl
resource "random_pet" "my-pet" {
  prefix = var.prefix[2]  # Changed from [0] to [2]
}
```

<img width="570" height="150" alt="main.tf showing change from var.prefix[0] to var.prefix[2]" src="images/05-change-prefix-to-2.png" />

Running `terraform plan`:

<img width="1160" height="300" alt="terraform plan showing -/+ replacement, prefix changing from Mr to Sir" src="images/06-terraform-plan-replacement.png" />

The plan shows `-/+ (destroy and replace)` because accessing `var.prefix[2]` now means "Sir" instead of "Mr". Since `prefix` is marked as ForceNew in the `random` provider, this triggers a replacement.

Running `terraform apply`:

<img width="1160" height="400" alt="terraform apply destroying old resource and creating new one with Sir prefix" src="images/07-terraform-apply-replacement.png" />

Old resource destroyed: `Mr-delicate-quetzal`
New resource created: **`Sir-singular-wahoo`** — using position 2 ("Sir") from the list.

Final state:

<img width="720" height="240" alt="terraform show: random_pet now has Sir prefix, id=Sir-singular-wahoo" src="images/08-terraform-show-after.png" />

## Lab 2: Set Variables and Duplicate Handling

### Setup

Created `set-practice` directory with set variables that include duplicates.

**variable.tf (with both WRONG and CORRECT versions):**

<img width="1160" height="500" alt="variable.tf showing set type variables with duplicates marked as WRONG and correct versions" src="images/09-set-variable-both.png" />

```hcl
# ❌ WRONG - duplicates in set
variable "unique_names" {
  type    = set(string)
  default = ["Alice", "Bob", "Alice"]  # Duplicate "Alice"
}

# ✅ CORRECT
variable "unique_names_correct" {
  type    = set(string)
  default = ["Alice", "Bob", "Charlie"]
}

# ❌ WRONG - duplicate numbers
variable "unique_ports" {
  type    = set(number)
  default = [8080, 9090, 8080]  # Duplicate 8080
}

# ✅ CORRECT
variable "unique_ports_correct" {
  type    = set(number)
  default = [8080, 9090, 3000]
}
```

**main.tf (using only the WRONG variables):**

<img width="1160" height="280" alt="main.tf with outputs referencing var.unique_names and var.unique_ports (the ones with duplicates)" src="images/10-set-main-tf.png" />

```hcl
resource "random_pet" "test" {
  prefix = "test"
}

output "names" {
  value = var.unique_names
}

output "ports" {
  value = var.unique_ports
}
```

### Expected vs. Actual Behavior

**Theory:** Sets don't allow duplicates, so this should ERROR.

**Reality:** Running `terraform plan`:

<img width="1160" height="500" alt="terraform plan output showing sets silently removed duplicates: names=[Alice, Bob], ports=[8080, 9090]" src="images/11-set-plan-duplicates-removed.png" />

```
Changes to Outputs:
  + names = [
      + "Alice",
      + "Bob",
    ]
  + ports = [
      + 8080,
      + 9090,
    ]
```

**Terraform silently removed the duplicates:**
- `["Alice", "Bob", "Alice"]` → `["Alice", "Bob"]` (removed duplicate "Alice")
- `[8080, 9090, 8080]` → `[8080, 9090]` (removed duplicate 8080)

Running `terraform apply`:

<img width="1160" height="500" alt="terraform apply showing outputs with duplicates removed, resource created successfully" src="images/12-set-apply-output.png" />

```
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

names = toset([
  "Alice",
  "Bob",
])
ports = toset([
  8080,
  9090,
])
```

**Key Learning:** Sets automatically enforce uniqueness without erroring — Terraform just removes duplicates for you.

## Lab 3: Type Mismatch and Automatic Conversion

### Setup

Created `type-mismatch-practice` directory with intentional type mismatches.

**variable.tf (only WRONG versions):**

<img width="1160" height="300" alt="variable.tf showing type mismatches: port as string 8080, file_path as number 123" src="images/13-type-mismatch-variable.png" />

```hcl
# ❌ WRONG - string instead of number
variable "port" {
  type    = number
  default = "8080"  # This is a string, not a number
}

# ❌ WRONG - number instead of string
variable "file_path" {
  type    = string
  default = 123  # This is a number
}
```

**main.tf (using the mismatched variables):**

<img width="1160" height="200" alt="main.tf with outputs referencing var.port and var.file_path" src="images/14-type-mismatch-main.png" />

```hcl
output "port" {
  value = var.port
}

output "file_path" {
  value = var.file_path
}
```

### Expected vs. Actual Behavior

**Theory:** Type mismatch (string when number expected, number when string expected) should ERROR.

**Reality:** Running `terraform apply`:

<img width="1160" height="350" alt="terraform apply showing type conversion: port=8080 (converted to number), file_path=123 (converted to string)" src="images/15-type-mismatch-apply.png" />

```
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

file_path = "123"
port      = 8080
```

**Terraform silently converted the types:**
- `"8080"` (string) automatically became `8080` (number)
- `123` (number) automatically became `"123"` (string)

## Key Learnings

### Terraform is Forgiving, Not Strict

Unlike many programming languages that error on type mismatches or duplicate values in sets, Terraform:

1. **Sets with duplicates** — Silently removes duplicates, converts to proper set
2. **Type mismatches (string ↔ number)** — Silently converts between the two
3. **No errors thrown** — Terraform just fixes the problem and applies normally

### This is Actually Safe

The forgiving behavior protects against common mistakes:
- You accidentally put quotes around a number? Terraform converts it.
- You have a duplicate in a set? Terraform removes it.
- Your code still works instead of breaking.

However, this also means you need to **be careful** — mistakes might silently convert instead of alerting you. Always review your `terraform plan` output carefully.

### What Still Matters

Terraform **will** error on:
- Completely incompatible types (trying to use an object as a string with no conversion path)
- Missing required variables
- Syntax errors in HCL

But for simple types (string, number) and collections, Terraform is lenient and fixes most issues automatically.

---
**Summary:** The three hands-on labs showed that Terraform's actual behavior is more forgiving than the theoretical rules suggest. It silently fixes duplicates in sets and automatically converts between simple types rather than erroring. This makes Terraform practical and user-friendly, but also means you should always verify your plan output carefully.
