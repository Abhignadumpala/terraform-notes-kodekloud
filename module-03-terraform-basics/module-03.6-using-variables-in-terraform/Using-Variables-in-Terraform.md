# 3.6: Using Variables in Terraform

> Master all techniques to pass input variables in Terraform including default values, command line input, environment variables, and variable definition precedence.

---

## Table of Contents
1. [What are Terraform Variables?](#what-are-terraform-variables)
2. [5 Ways to Provide Variable Values](#5-ways-to-provide-variable-values)
3. [Variable Definition Precedence](#variable-definition-precedence)
4. [Key Takeaways](#key-takeaways)

---

## What are Terraform Variables?

Variables in Terraform allow you to:
- ✅ Avoid hardcoding values
- ✅ Reuse configurations across environments
- ✅ Make configurations flexible and maintainable
- ✅ Pass dynamic values at runtime

Think of them like function parameters in programming.

---

## 5 Ways to Provide Variable Values

### Method 1: Default Values with Variable Blocks

By assigning default values directly within your variable blocks, you ensure that Terraform uses these values if no alternative is provided. For example, consider the following configuration that creates a local file resource and a random pet resource:

**File: `main.tf`**
```hcl
resource "local_file" "pet" {
  filename = var.filename
  content  = var.content
}

resource "random_pet" "my-pet" {
  prefix    = var.prefix
  separator = var.separator
  length    = var.length
}
```

**File: `variables.tf`**
```hcl
variable "filename" {
  default = "/root/pets.txt"
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
  default = 2
}
```

In this example, each variable is provided with a default value. This approach ensures that Terraform has a fallback value when none is explicitly supplied, making your configurations more robust.

**✅ Pros:**
- Simple and reliable
- Good for common, unchanging values
- No setup needed
- Works everywhere without configuration
- Easy to understand for beginners
- Great for development environments

**❌ Cons:**
- Can't change without editing the file
- Not flexible for different environments
- Hardcoded values in code
- Changes require code commit
- Not suitable for sensitive data
- Must modify and redeploy for different values

---

### Method 2: Interactive Prompts and Command-Line Input

If a variable does not have a default value or if you want to override an existing default, Terraform will prompt you for a value during `terraform apply`. To streamline automation and avoid interactive prompts, you can pass values using the `-var` flag. You can supply multiple `-var` flags as needed:

**Interactive Prompt Example:**
```hcl
# variables.tf
variable "filename" {
  # No default = Terraform will ask during apply
  type = string
}
```

**Command:**
```bash
$ terraform apply
# Output:
# var.filename
#   Enter a value: /root/my-file.txt
```

**Command-Line Flag Example:**
```bash
$ terraform apply -var "filename=/root/newfile.txt" -var "content=Hello, Terraform!"
```

**Multiple Variables:**
```bash
$ terraform apply \
  -var "filename=/root/pets.txt" \
  -var "content=We love pets!" \
  -var "prefix=Mrs" \
  -var "separator=." \
  -var "length=2"
```

**✅ Pros (Interactive):**
- Good for one-off testing
- Easy to experiment with values
- No need to remember flags or files
- Useful for interactive debugging

**❌ Cons (Interactive):**
- Can't automate (interactive prompts block CI/CD)
- Slows down deployments
- Not suitable for production
- Easy to make typos
- Requires manual input every time

**✅ Pros (Command-Line Flags):**
- Automatable (no interactive prompts)
- Can override defaults and other sources
- **HIGHEST PRIORITY** - always wins!
- Perfect for CI/CD pipelines
- Easy to see what values are being used
- Good for one-time deployments

**❌ Cons (Command-Line Flags):**
- Long command lines get messy with many variables
- Hard to read and maintain
- Easy to make mistakes with special characters
- Need to escape quotes carefully
- Can exceed command-line length limits
- Difficult to track in deployment history
- Values visible in shell history

---

### Method 3: Environment Variables Setup

Alternatively, you can set environment variables by prefixing the variable name with `TF_VAR_`. For example, you can configure your shell as follows:

```bash
$ export TF_VAR_filename="/root/pets.txt"
$ export TF_VAR_content="We love pets!"
$ export TF_VAR_prefix="Mrs"
$ export TF_VAR_separator="."
$ export TF_VAR_length="2"
$ terraform apply
```

In this scenario, Terraform automatically picks up the environment variable values during execution, providing a convenient method for variable assignment.

**✅ Pros:**
- Clean and organized
- Perfect for secrets and sensitive data (API keys, passwords)
- Cross-platform compatible (Linux, Mac, Windows)
- Easy to set once and reuse multiple times
- Good for CI/CD with secret management
- Can be set in CI/CD systems without exposing in logs
- Good for different environments

**❌ Cons:**
- Need to set up environment first
- Can be forgotten between sessions
- Need to remember `TF_VAR_` prefix
- Different for each shell/terminal session
- Can be confusing which env vars are set
- Not persistent across reboots (unless in .bashrc)
- Variables can be exposed if not careful with history
- Hard to see all variables at once

---

### Method 4: Using Variable Definition Files

When managing many variables, it becomes practical to store their values in a dedicated variable definition file. These files typically have a `.tfvars` or `.tfvars.json` extension. For example, you can create a file named `terraform.tfvars` with the following contents:

```hcl
filename = "/root/pets.txt"
content  = "We love pets!"
prefix   = "Mrs"
separator = "."
length   = "2"
```

Terraform automatically loads files named `terraform.tfvars`, `terraform.tfvars.json`, or files with extensions like `.auto.tfvars` or `.auto.tfvars.json`. If you use a differently named file (e.g., `variables.tfvars`), be sure to specify it explicitly with the `-var-file` flag:

```bash
$ terraform apply -var-file="variables.tfvars"
```

This approach centralizes your variable definitions and simplifies the management of Terraform environments.

**Environment-Specific Files:**
```bash
# Development
$ terraform apply -var-file="dev.tfvars"

# Staging
$ terraform apply -var-file="staging.tfvars"

# Production
$ terraform apply -var-file="prod.tfvars"
```

**✅ Pros:**
- Centralized and organized
- Easy to manage many variables in one place
- Perfect for environment-specific configurations
- Readable and maintainable HCL format
- Easy to version control different environments
- Can commit to git (if no secrets)
- Easy to share with team members
- Clear separation of config values

**❌ Cons:**
- Another file to manage and maintain
- Can be overlooked or forgotten in git
- Need to remember to specify `-var-file` for custom names
- Danger of committing secrets to git (use `.gitignore`!)
- Multiple files can be confusing
- Easy to mix up which file is for which environment
- Requires discipline to keep organized
- File structure can get complex with many environments

---

### Method 5: Combination Approach - Multiple Sources

You can also combine multiple methods for maximum flexibility:

```bash
# Start with defaults in variables.tf
# Add environment-specific values in dev.tfvars
# Override with command-line flags for special cases
$ terraform apply -var-file="dev.tfvars" -var "instance_count=5"
```

**Project Structure Example:**
```
.
├── main.tf
├── variables.tf
├── terraform.tfvars           # Default/common values
├── dev.tfvars                 # Development overrides
├── staging.tfvars             # Staging overrides
└── prod.tfvars                # Production overrides
```

**✅ Pros:**
- Maximum flexibility
- Can handle complex scenarios
- Easy to debug different configurations
- Good for different team needs

**❌ Cons:**
- Can become confusing
- Hard to track which value is being used
- Requires understanding precedence rules
- Multiple files to maintain

---

## Variable Definition Precedence

Terraform allows you to set variable values from multiple sources. When the same variable is defined in multiple places, Terraform uses a specific order of precedence to determine which value to apply. Consider the following scenario where a variable is defined in various ways:

* **Environment Variable:**
  ```bash
  $ export TF_VAR_filename="/root/cats.txt"
  ```

* **terraform.tfvars File:**
  ```hcl
  filename = "/root/pets.txt"
  ```

* **File Ending with .auto.tfvars:**
  ```hcl
  filename = "/root/mypet.txt"
  ```

* **Command-Line Flag:**
  ```bash
  $ terraform apply -var "filename=/root/best-pet.txt"
  ```

Below is the sample configuration file:

```hcl
# main.tf
resource "local_file" "pet" {
  filename = var.filename
}

# variables.tf
variable "filename" {
  type = string
}
```

Terraform follows this strict order of precedence when assigning variable values:

| Precedence Level | Example Call or File | Value Used |
|---|---|---|
| 1. Environment variables (`TF_VAR_`) | `export TF_VAR_filename="/root/cats.txt"` | `/root/cats.txt` |
| 2. terraform.tfvars file | `filename = "/root/pets.txt"` | `/root/pets.txt` |
| 3. Files ending with `.auto.tfvars` or `.auto.tfvars.json` | `filename = "/root/mypet.txt"` | `/root/mypet.txt` |
| 4. Command-line flags (`-var` or `-var-file`) | `terraform apply -var "filename=/root/best-pet.txt"` | `/root/best-pet.txt` |

Since the command-line flag (`-var`) has the highest precedence in this example, the variable `filename` will ultimately be assigned the value `/root/best-pet.txt`.

**Remember:** The order in which variable values are applied ensures predictability in your deployment. This hierarchy allows you to override defaults and maintain control over your configuration settings.

---

## Key Takeaways

✅ **Use default values** for common, unchanging configuration  
✅ **Use `-var` flags** for automation and CI/CD pipelines  
✅ **Use environment variables** for secrets and sensitive data  
✅ **Use `.tfvars` files** for organizing multiple variables and environments  
✅ **Remember precedence:** Command-line flags always win!  
✅ **Test your precedence:** Verify which value is being used in conflicts  
✅ **Combine methods** for maximum flexibility and control  


