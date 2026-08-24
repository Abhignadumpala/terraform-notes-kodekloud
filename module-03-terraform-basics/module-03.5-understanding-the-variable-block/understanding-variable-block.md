# 3.5: Understanding the Variable Block

This article explores the Terraform variable block, including variable definition, type constraints, and complex data structures for efficient infrastructure code.

In this lesson, we take an in-depth look at the Terraform variable block, exploring how to define variables, enforce type constraints, and work with complex data structures. Learn how to leverage Terraform's variable capabilities to write more efficient and maintainable infrastructure code.

## Basic Variable Definition

Terraform variable blocks can include several parameters, including a default value that sets a fallback for the variable. Below is an example that defines several variables with default values:

```hcl
variable "filename" {
  default = "/home/sri-abhi/pets.txt"
}

variable "content" {
  default = "We love pets!"
}

variable "prefix" {
  default = "Mrs"
}

variable "separator" {
  default = "."
}

variable "length" {
  default = 1
}
```

Terraform variable blocks can also include the optional parameters `type` and `description`. The `description` provides clarity on the variable's purpose, while the `type` enforces the kind of data the variable can hold. For example:

```hcl
variable "filename" {
  default     = "/home/sri-abhi/pets.txt"
  type        = string
  description = "The path of the local file"
}

variable "content" {
  default     = "We love pets!"
  type        = string
  description = "The content of the file"
}

variable "prefix" {
  default     = "Mrs"
  type        = string
  description = "The prefix to be set"
}

variable "separator" {
  default = "."
}

variable "file_permission" {
  default     = "0700"
  type        = string
  description = "File permission in octal format"
}

variable "length" {
  default     = 1
  type        = number
  description = "Length of the random suffix"
}
```

If a type constraint is not specified, Terraform defaults to the type "Any".

## Simple Variable Types

Terraform supports several simple variable types. Here's a quick overview:

* **String** — Accepts alphanumeric values.
* **Number** — Accepts numeric values (both positive and negative).
* **Boolean** — Accepts values of either `true` or `false`.

In addition to these, Terraform supports more advanced types such as list, map, set, object, and tuple.

## Collection Types — List

A list is an **ordered collection of values where each element can be accessed by its index** (starting at 0). All values in a list must be **of the same type** — either all strings, all numbers, or all booleans, but not mixed.

For example, consider a variable that uses a list of prefixes:

```hcl
variable "prefix" {
  default = ["Mr", "Mrs", "Sir"]
  type    = list(string)
}

resource "random_pet" "my-pet" {
  prefix = var.prefix[0]
}
```

In this configuration:

* `var.prefix[0]` returns "Mr"
* `var.prefix[1]` returns "Mrs"
* `var.prefix[2]` returns "Sir"

Lists are useful when you need to maintain order and allow duplicate values. You can iterate over lists using `for_each` or `for` loops:

```hcl
variable "backup_locations" {
  default = [
    "/home/sri-abhi/backups/pets.txt.bak1",
    "/home/sri-abhi/backups/pets.txt.bak2",
    "/home/sri-abhi/backups/pets.txt.bak3"
  ]
  type        = list(string)
  description = "List of backup file paths"
}

resource "local_file" "backups" {
  for_each = toset(var.backup_locations)
  
  filename = each.value
  content  = "Backup of pets file"
}
```

## Collection Types — Map

A map is a **collection of key-value pairs**. Instead of accessing by position like a list, you access by key name.

```hcl
variable "file_contents" {
  type = map(string)
  default = {
    "statement1" = "We love pets!"
    "statement2" = "We love animals!"
  }
}
```

Accessing items in a map:

```hcl
var.file_contents["statement1"]  # Returns "We love pets!"
var.file_contents["statement2"]  # Returns "We love animals!"
```

## Collection Types — Set

Sets in Terraform are similar to lists but automatically remove duplicate elements. Consider these examples of valid set declarations:

```hcl
variable "prefix" {
  default = ["Mr", "Mrs", "Sir"]
  type    = set(string)
}

variable "fruit" {
  default = ["apple", "banana"]
  type    = set(string)
}

variable "age" {
  default = [10, 12, 15]
  type    = set(number)
}
```

**Terraform's Forgiving Behavior:**

If you accidentally include duplicate values, Terraform **silently removes them** — no error is thrown:

```hcl
variable "prefix" {
  default = ["Mr", "Mrs", "Sir", "Sir"]  # Duplicate "Sir" will be removed
  type    = set(string)
}

variable "fruit" {
  default = ["apple", "banana", "banana"]  # Duplicate "banana" will be removed
  type    = set(string)
}

variable "age" {
  default = [10, 12, 15, 10]  # Duplicate 10 will be removed
  type    = set(number)
}
```

Additionally, if you provide a value with the wrong type, Terraform **automatically converts** it:

- **Type `string` with number value:** Terraform adds quotes to convert it to string
  ```hcl
  variable "port" {
    type    = string
    default = 8080  # Number, but type expects string → becomes "8080"
  }
  ```

- **Type `number` with string value:** Terraform removes quotes to convert it to number
  ```hcl
  variable "count" {
    type    = number
    default = "5"  # String, but type expects number → becomes 5
  }
  ```

Sets are unordered collections of unique values. They are useful when you need to ensure uniqueness and don't care about order:

```hcl
variable "unique_regions" {
  default = ["us-east-1", "us-west-2", "eu-west-1"]
  type    = set(string)
  description = "Unique AWS regions (duplicates auto-removed)"
}

resource "aws_instance" "example" {
  for_each          = var.unique_regions
  ami               = "ami-0c55b159cbfafe1f0"
  instance_type     = "t2.micro"
  availability_zone = each.value
}
```

## Complex Types — Object

An object is a **structure with multiple named fields, each with its own type**. Think of it like a database record.

```hcl
variable "pet_info" {
  type = object({
    name         = string
    age          = number
    is_favorite  = bool
  })
  default = {
    name        = "Bella"
    age         = 5
    is_favorite = true
  }
}
```

Accessing object fields:

```hcl
var.pet_info.name        # Returns "Bella"
var.pet_info.age         # Returns 5
var.pet_info.is_favorite # Returns true
```

## Complex Types — Tuple

A tuple is **like a list, but with fixed length and specific types at each position**.

```hcl
variable "pet_details" {
  type    = tuple([string, number, bool])
  default = ["cat", 7, true]
}
```

This means:
- Position 0 must be a string
- Position 1 must be a number
- Position 2 must be a boolean

---
**Reference:** [Terraform Variables — developer.hashicorp.com](https://developer.hashicorp.com/terraform/language/values/variables)
