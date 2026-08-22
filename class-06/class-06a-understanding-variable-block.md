# Understanding the Variable Block

> This article explores the Terraform variable block, including variable definition, type constraints, and complex data structures for efficient infrastructure code.

In this lesson, we take an in-depth look at the Terraform variable block, exploring how to define variables, enforce type constraints, and work with complex data structures. Learn how to leverage Terraform's variable capabilities to write more efficient and maintainable infrastructure code.

***

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

***

## Simple Variable Types

Terraform supports several simple variable types. Here's a quick overview:

* **String:** Accepts alphanumeric values.
* **Number:** Accepts numeric values (both positive and negative).
* **Boolean:** Accepts values of either `true` or `false`.

In addition to these, Terraform supports more advanced types such as list, map, set, object, and tuple.

***

## List Variables

A list is an ordered collection of values where each element can be accessed by its index (starting at 0). For example, consider a variable that uses a list of prefixes:

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

***

## Map Variables

Maps allow you to define key-value pairs for storing related data. For example, the following variable stores file content:

```hcl
variable "file_content" {
  type    = map(string)
  default = {
    "statement1" = "We love pets!"
    "statement2" = "We love animals!"
  }
}
```

To reference a specific value from this map in a resource, use the key inside square brackets:

```hcl
resource "local_file" "my-pet" {
  filename = "/home/sri-abhi/pets.txt"
  content  = var.file_content["statement2"]
}
```

This fetches the value "We love animals!" from the map.

Maps are unordered, meaning the order of key-value pairs is not guaranteed. They are ideal for lookups where you need to access values by their keys:

```hcl
variable "pet_attributes" {
  type = map(string)
  default = {
    "name"   = "Bella"
    "color"  = "brown"
    "breed"  = "Persian"
  }
  description = "Pet attributes stored as key-value pairs"
}

variable "pet_count" {
  type = map(number)
  default = {
    "dogs"     = 3
    "cats"     = 1
    "goldfish" = 2
  }
  description = "Count of different pet types"
}

resource "local_file" "pet_summary" {
  filename = "/home/sri-abhi/pets.txt"
  content  = "Name: ${var.pet_attributes["name"]}, Dogs: ${var.pet_count["dogs"]}"
}
```

***

## List and Map Type Constraints

You can enforce type constraints on lists and maps to ensure all elements are of a specific type. For example:

```hcl
variable "prefix" {
  default = ["Mr", "Mrs", "Sir"]
  type    = list(string)
}

variable "numbers" {
  default = [1, 2, 3]
  type    = list(number)
}
```

Similarly, you can enforce type constraints on maps:

```hcl
variable "cats" {
  default = {
    "color" = "brown"
    "name"  = "bella"
  }
  type = map(string)
}

variable "pet_count" {
  default = {
    "dogs"     = 3
    "cats"     = 1
    "goldfish" = 2
  }
  type = map(number)
}
```

If the default values do not match the declared type, Terraform will produce an error when running `terraform plan` or `terraform apply`. For instance, using a string when a number is required will trigger an error.

***

## Set Variables

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

Using duplicate values will trigger an error:

```hcl
variable "prefix" {
  default = ["Mr", "Mrs", "Sir", "Sir"]
  type    = set(string)
}

variable "fruit" {
  default = ["apple", "banana", "banana"]
  type    = set(string)
}

variable "age" {
  default = [10, 12, 15, 10]
  type    = set(number)
}
```

Ensure that when using sets, duplicate values are removed to avoid configuration errors.

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

***

## Object Variables

Objects allow you to create complex structures by combining various data types. For example, you can define an object representing a cat with multiple attributes:

```hcl
variable "bella" {
  type = object({
    name         = string
    color        = string
    age          = number
    food         = list(string)
    favorite_pet = bool
  })
}
```

Assign default values that adhere to the defined structure:

```hcl
variable "bella" {
  type    = object({
    name         = string
    color        = string
    age          = number
    food         = list(string)
    favorite_pet = bool
  })
  default = {
    name         = "Bella"
    color        = "brown"
    age          = 7
    food         = ["fish", "chicken", "turkey"]
    favorite_pet = true
  }
  description = "Complete pet information object"
}

resource "local_file" "pet_details" {
  filename = "/home/sri-abhi/pets.txt"
  content  = <<-EOT
    Pet Name: ${var.bella.name}
    Color: ${var.bella.color}
    Age: ${var.bella.age}
    Foods: ${join(", ", var.bella.food)}
  EOT
}
```

Objects can also be nested to create more complex data structures:

```hcl
variable "infrastructure" {
  type = object({
    database = object({
      engine   = string
      version  = string
      instance = string
    })
    storage = object({
      bucket_name = string
      versioning  = bool
      tags        = map(string)
    })
  })
  default = {
    database = {
      engine   = "postgres"
      version  = "13.7"
      instance = "db.t3.micro"
    }
    storage = {
      bucket_name = "my-pet-storage"
      versioning  = true
      tags = {
        environment = "production"
        team        = "platform"
      }
    }
  }
  description = "Complete infrastructure configuration"
}
```

***

## Tuple Variables

Tuples in Terraform are like lists but allow elements of different types. The order and type of the elements are strictly defined. For example, consider this tuple variable:

```hcl
variable "kitty" {
  type    = tuple([string, number, bool])
  default = ["cat", 7, true]
}
```

This tuple expects exactly three elements: a string, a number, and a boolean. Adding an extra element or an incorrect type will produce an error:

```hcl
variable "kitty" {
  type    = tuple([string, number, bool])
  default = ["cat", 7, true, "dog"]  # This will cause an error.
}
```

Running `terraform plan` with the above configuration will generate an error indicating that the default value does not match the tuple's required type structure.

Tuples are useful when you need a fixed-length collection with specific types at each position:

```hcl
variable "pet_info" {
  type    = tuple([string, number, bool])
  default = ["Bella", 7, true]
  description = "Pet information: [name, age, is_favorite]"
}

locals {
  pet_name     = var.pet_info[0]  # "Bella" (string)
  pet_age      = var.pet_info[1]  # 7 (number)
  is_favorite  = var.pet_info[2]  # true (bool)
}

resource "local_file" "pet_info" {
  filename = "/home/sri-abhi/pets.txt"
  content  = "${local.pet_name} is ${local.pet_age} years old"
}
```

***

## Any Type

When you don't specify a type, Terraform defaults to the type `any`. This is the most flexible but least type-safe option:

```hcl
variable "flexible_input" {
  default = "could be anything"
  # No type specified = type is 'any'
  description = "This variable accepts any type of value"
}

variable "config_data" {
  # This accepts strings, numbers, lists, objects, etc.
  description = "Flexible configuration data"
}
```

The `any` type is useful when you truly need flexibility during development or testing, but it's not recommended for production code as it reduces type safety and makes your configuration harder to understand and maintain. Instead, use specific types whenever possible.

***

## Sensitive Variables

Sensitive variables hide their values from logs and output. This is important for protecting passwords, API tokens, and other secrets:

```hcl
variable "db_password" {
  type        = string
  description = "Database password"
  sensitive   = true  # Redacts value in terraform plan/apply output
}

variable "api_token" {
  type        = string
  sensitive   = true
  default     = "secret-token-123"
  description = "API authentication token"
}
```

When you mark a variable as sensitive, Terraform will show `<sensitive>` instead of the actual value in the output:

```
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

api_endpoint = "https://api.example.com"
password = <sensitive>
```

Use sensitive for any credential or secret that should not be displayed in logs or output.

***

## Nullable Variables

By default, variables cannot be `null`. Use `nullable = true` to allow optional values:

```hcl
# This will cause an error
variable "optional_value" {
  type    = string
  default = null  # ERROR!
}

# This is correct
variable "optional_value" {
  type        = string
  nullable    = true
  default     = null  # OK
  description = "Optional value, can be null"
}

variable "backup_enabled" {
  type        = bool
  nullable    = true
  default     = null
  description = "Enable backups (null = not specified)"
}
```

Nullable variables are useful for optional configurations where not providing a value is different from providing a false or empty value.

***

## Variable Validation

You can add custom validation rules to enforce constraints on variable values:

```hcl
variable "instance_count" {
  type        = number
  description = "Number of instances to create"
  
  validation {
    condition     = var.instance_count > 0 && var.instance_count <= 100
    error_message = "Instance count must be between 1 and 100."
  }
}

variable "environment" {
  type        = string
  description = "Environment name"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "email" {
  type        = string
  description = "Email address"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.email))
    error_message = "Must be a valid email address."
  }
}
```

If a value doesn't match the validation condition, Terraform will produce an error with your custom message.

***

## Variable Definition Precedence

When you run Terraform, it loads variable values from multiple sources in this order (highest to lowest priority):

1. **Command-line flags** - `terraform apply -var="key=value"`
2. **Variable files** - `*.tfvars` files
3. **Environment variables** - `TF_VAR_name=value`
4. **Default values** - Specified in variable block
5. **Interactive prompt** - If no value provided and no default exists

For example, with this variable:

```hcl
variable "environment" {
  type    = string
  default = "dev"
}
```

You can override the default in multiple ways:

```bash
# 1. Use default
terraform apply  # Uses "dev"

# 2. Use .tfvars file
terraform apply -var-file="prod.tfvars"

# 3. Use command-line
terraform apply -var="environment=staging"

# 4. Use environment variable
export TF_VAR_environment="prod"
terraform apply
```

***

## Comprehensive Variable Types Comparison

Here is a comparison of all variable types:

| Type | Example | Ordered? | Unique Only? | Fixed Length? | Mixed Types? | Use Case |
|------|---------|----------|--------------|---------------|--------------|----------|
| **string** | `"Hello"` | N/A | N/A | N/A | N/A | Text values, paths, identifiers |
| **number** | `42`, `3.14` | N/A | N/A | N/A | N/A | Counts, ports, sizes, timeouts |
| **bool** | `true`/`false` | N/A | N/A | N/A | N/A | Feature flags, conditions |
| **list** | `["a", "b", "c"]` | ✅ Yes | ❌ No | ❌ No | ❌ No | Ordered collections of same type |
| **map** | `{key = value}` | ❌ No | ❌ No | ❌ No | ❌ No | Key-value lookups, attributes |
| **set** | `["a", "b"]` | ❌ No | ✅ Yes | ❌ No | ❌ No | Unique collections, no order |
| **object** | `{name = "x", age = 5}` | N/A | N/A | ✅ Yes | ✅ Yes | Structured data with named fields |
| **tuple** | `["str", 5, true]` | ✅ Yes | N/A | ✅ Yes | ✅ Yes | Fixed-length with mixed types |
| **any** | Any valid value | N/A | N/A | N/A | N/A | Flexible input, no type constraint |

***

## Common Variable Mistakes

Understanding common mistakes can help you avoid errors and write better Terraform configurations. Here are the most frequent issues:

### Mistake 1: Type Mismatch

One of the most common errors is providing a default value that doesn't match the declared type.

```hcl
# ❌ WRONG - string instead of number
variable "port" {
  type    = number
  default = "8080"  # This is a string, not a number
}

# ✅ CORRECT
variable "port" {
  type    = number
  default = 8080  # Actual number without quotes
}

# ❌ WRONG - number instead of string
variable "file_path" {
  type    = string
  default = 123  # This is a number
}

# ✅ CORRECT
variable "file_path" {
  type    = string
  default = "123"  # String with quotes
}
```

**Error Message You'll See:**
```
Error: Unsupported argument

  on variables.tf line 3, in variable "port":
   3:   default = "8080"

An argument named "default" is not expected here. Did you mean "default"?
```

### Mistake 2: Missing Quotes for Strings

String values must always be quoted in HCL syntax.

```hcl
# ❌ WRONG - unquoted string
variable "content" {
  type    = string
  default = We love pets!  # Missing quotes - syntax error
}

# ✅ CORRECT
variable "content" {
  type    = string
  default = "We love pets!"  # Properly quoted
}

# ❌ WRONG - file path without quotes
variable "filename" {
  type    = string
  default = /home/sri-abhi/pets.txt  # Missing quotes
}

# ✅ CORRECT
variable "filename" {
  type    = string
  default = "/home/sri-abhi/pets.txt"  # Properly quoted
}
```

### Mistake 3: List Element Type Mismatch

All elements in a list must be of the same type as declared.

```hcl
# ❌ WRONG - mixed types in list(string)
variable "prefixes" {
  type    = list(string)
  default = ["Mr", "Mrs", 123]  # 123 is a number, not a string
}

# ✅ CORRECT
variable "prefixes" {
  type    = list(string)
  default = ["Mr", "Mrs", "Sir"]  # All strings
}

# ❌ WRONG - mixed types in list(number)
variable "ages" {
  type    = list(number)
  default = [10, "20", 30]  # "20" is a string
}

# ✅ CORRECT
variable "ages" {
  type    = list(number)
  default = [10, 20, 30]  # All numbers
}
```

### Mistake 4: Duplicates in Sets

Sets automatically remove duplicates, but specifying them causes errors.

```hcl
# ❌ WRONG - duplicates in set
variable "unique_names" {
  type    = set(string)
  default = ["Alice", "Bob", "Alice"]  # Duplicate "Alice"
}

# ✅ CORRECT
variable "unique_names" {
  type    = set(string)
  default = ["Alice", "Bob", "Charlie"]  # No duplicates
}

# ❌ WRONG - duplicate numbers
variable "unique_ports" {
  type    = set(number)
  default = [8080, 9090, 8080]  # Duplicate 8080
}

# ✅ CORRECT
variable "unique_ports" {
  type    = set(number)
  default = [8080, 9090, 3000]  # All unique
}
```

### Mistake 5: Not Specifying Type

While optional, omitting the `type` parameter reduces type safety.

```hcl
# ❌ RISKY - no type specified (defaults to 'any')
variable "config" {
  default = "some value"
  description = "Configuration value"
}

# ✅ BETTER - specify type
variable "config" {
  type        = string
  default     = "some value"
  description = "Configuration value"
}
```

Without specifying `type`, Terraform accepts any value type, making your configuration unpredictable and hard to debug.

### Mistake 6: Missing Description

Omitting descriptions makes your variables unclear to other users.

```hcl
# ❌ NOT RECOMMENDED - no description
variable "filename" {
  type    = string
  default = "/home/sri-abhi/pets.txt"
}

# ✅ RECOMMENDED - clear description
variable "filename" {
  type        = string
  default     = "/home/sri-abhi/pets.txt"
  description = "Path to the pets file where pet data is stored"
}
```

### Mistake 7: Storing Secrets in Plain Text

Never store passwords or tokens as plain default values without marking them as sensitive.

```hcl
# ❌ DANGEROUS - secret visible in logs
variable "db_password" {
  type    = string
  default = "my-secret-password-123"
  # Password will be exposed in terraform plan/apply output
}

# ✅ SECURE - marked as sensitive
variable "db_password" {
  type        = string
  default     = "my-secret-password-123"
  sensitive   = true  # Redacts from output
  description = "Database password"
}

# ✅ EVEN BETTER - no default for secrets
variable "db_password" {
  type        = string
  sensitive   = true
  description = "Database password - provide via -var or environment"
  # No default - requires explicit input
}
```

### Mistake 8: Wrong Map Value Type

Map values must all be of the same type as declared.

```hcl
# ❌ WRONG - mixed value types in map(string)
variable "pet_info" {
  type = map(string)
  default = {
    "name" = "Bella"
    "age"  = 7  # This is a number, not a string
  }
}

# ✅ CORRECT - all values are strings
variable "pet_info" {
  type = map(string)
  default = {
    "name" = "Bella"
    "age"  = "7"  # Converted to string
  }
}

# ✅ BETTER APPROACH - use map(number) for ages
variable "pet_ages" {
  type = map(number)
  default = {
    "bella" = 7
    "max"   = 5
  }
}
```

### Mistake 9: Confusing Objects with Maps

Objects have fixed, named attributes. Maps are flexible key-value pairs.

```hcl
# ❌ WRONG - trying to use object like a map
variable "pet_data" {
  type = object({
    name = string
    age  = number
  })
  default = {
    "name" = "Bella"
    "age"  = 7
    "breed" = "Persian"  # Extra field not defined in object
  }
  # This will cause an error - object structure doesn't match
}

# ✅ CORRECT - use object with fixed attributes
variable "pet_data" {
  type = object({
    name  = string
    age   = number
    breed = string  # Define all attributes
  })
  default = {
    name  = "Bella"
    age   = 7
    breed = "Persian"
  }
}

# ✅ OR use map for flexible data
variable "pet_info" {
  type = map(string)  # Any key-value pairs
  default = {
    "name"  = "Bella"
    "age"   = "7"
    "breed" = "Persian"
    "color" = "brown"  # Can add any keys
  }
}
```

### Mistake 10: Tuple Length or Type Mismatch

Tuples have fixed length and each position has a specific type.

```hcl
# ❌ WRONG - extra element
variable "pet_info" {
  type    = tuple([string, number, bool])
  default = ["Bella", 7, true, "extra"]  # 4 elements instead of 3
}

# ❌ WRONG - wrong type at position
variable "pet_info" {
  type    = tuple([string, number, bool])
  default = ["Bella", "7", true]  # Second element should be number, not string
}

# ✅ CORRECT - exact structure
variable "pet_info" {
  type    = tuple([string, number, bool])
  default = ["Bella", 7, true]  # Exactly 3 elements with correct types
}
```

### Mistake 11: Using Null Without Nullable

Variables cannot contain null values unless explicitly marked as nullable.

```hcl
# ❌ WRONG - null without nullable = true
variable "optional_value" {
  type    = string
  default = null  # ERROR: null not allowed
}

# ✅ CORRECT - explicitly allow null
variable "optional_value" {
  type        = string
  nullable    = true
  default     = null  # OK - explicitly allowed
  description = "Optional value that can be null"
}
```

### Mistake 12: Bad Validation Conditions

Validation rules must have clear conditions and error messages.

```hcl
# ❌ WRONG - validation that's always true
variable "environment" {
  type        = string
  description = "Environment name"
  
  validation {
    condition     = true  # Always passes - useless
    error_message = "Invalid environment"
  }
}

# ❌ WRONG - confusing error message
variable "instance_count" {
  type = number
  
  validation {
    condition     = var.instance_count > 0
    error_message = "Error with instance"  # Vague message
  }
}

# ✅ CORRECT - clear condition and message
variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be 'dev', 'staging', or 'prod', got '${var.environment}'"
  }
}

variable "instance_count" {
  type        = number
  description = "Number of instances to create"
  
  validation {
    condition     = var.instance_count > 0 && var.instance_count <= 100
    error_message = "Instance count must be between 1 and 100, got ${var.instance_count}"
  }
}
```

### Mistake 13: Variable Naming Conventions

Use clear, consistent names for variables.

```hcl
# ❌ POOR - unclear names
variable "x" {
  type = string
}

variable "a1" {
  type = number
}

variable "foo_bar_baz" {
  type = bool
}

# ✅ BETTER - descriptive names
variable "app_name" {
  type = string
  description = "Name of the application"
}

variable "instance_count" {
  type = number
  description = "Number of instances to create"
}

variable "enable_backup" {
  type = bool
  description = "Enable automated backups"
}
```

### Mistake 14: Not Using Defaults for Production Values

Production configurations should have sensible defaults.

```hcl
# ❌ NO DEFAULT - forces manual input every time
variable "environment" {
  type = string
  # No default - risky for automation
}

# ✅ WITH DEFAULT - safer for production
variable "environment" {
  type        = string
  default     = "prod"  # Sensible default
  description = "Deployment environment"
}

# Note: You can still override with -var or environment variables
```

### Mistake 15: Conflicting Variable Names

Using variable names that conflict with reserved words or are ambiguous.

```hcl
# ❌ CONFUSING - uses reserved-like names
variable "resource" {
  type = string  # Too generic
}

variable "data" {
  type = map(any)  # Vague
}

# ✅ CLEAR - descriptive names
variable "aws_resource_arn" {
  type        = string
  description = "ARN of the AWS resource"
}

variable "user_metadata" {
  type        = map(string)
  description = "User metadata as key-value pairs"
}
```

These mistakes are easy to make but cause configuration errors or security issues. Always review your variable definitions carefully and follow Terraform best practices.

***

## Best Practices

When defining variables, follow these best practices:

- **Always specify `type`** - Provides type safety and clarity
- **Always add `description`** - Documents the variable's purpose
- **Use `sensitive = true`** - For passwords, tokens, and other secrets
- **Add validation blocks** - Enforce constraints and prevent errors
- **Group related variables** - Organize related configuration together
- **Use meaningful defaults** - Provide sensible production-ready defaults
- **Avoid `any` type** - Use specific types for better maintainability

***

## Summary

Terraform variables are essential for writing reusable and flexible infrastructure code. By understanding the different variable types and their constraints, you can create robust configurations that are easier to maintain and understand. Key takeaways:

- **Primitive types** (`string`, `number`, `bool`) handle simple values
- **Collection types** (`list`, `map`, `set`) manage multiple values of the same type
- **Complex types** (`object`, `tuple`) enable structured data with specific schemas
- **Special features** like `sensitive`, `nullable`, and `validation` add powerful capabilities
- **Type constraints** prevent errors and make code self-documenting

Use these tools effectively to build production-quality Terraform configurations.

***

**Resources:**
- [Terraform Documentation](https://www.terraform.io/docs)
- [Terraform Input Variables](https://www.terraform.io/docs/language/values/variables)
- [Terraform Type System](https://www.terraform.io/docs/language/expressions/types)
