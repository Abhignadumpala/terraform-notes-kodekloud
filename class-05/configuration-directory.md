# Class 5a: The Terraform Configuration Directory

This lesson covers the structure and naming conventions of a Terraform configuration directory, for better project organization and configuration management.

So far, I've worked with a single configuration file, `local.tf`, located in the `terraform-local-file` directory. Here's a listing of that directory along with the contents of `local.tf`: 

```bash
ls ~/terraform-local-file
```
```
local.tf
```
```hcl
resource "local_file" "pet" {
  filename = "/home/sri-abhi/pets.txt"
  content  = "We love pets!"
}
```

But Terraform doesn't actually care what a file is named, or whether there's just one. It reads **every file ending in `.tf`** in the working directory and treats them all as one combined configuration.

## Splitting Config Across Multiple Files

For example, adding a second file `cat.tf` in the same directory, defining another `local_file` resource:

```bash
ls ~/terraform-local-file
```
```
cat.tf  local.tf
```
```hcl
resource "local_file" "cat" {
  filename = "/home/sri-abhi/cat.txt"
  content  = "My favorite pet is Mr. Whiskers"
}
```

Running `terraform apply` in that directory processes **both** files together — `pets.txt` and `cat.txt` both get created, even though they're defined in separate `.tf` files. Terraform doesn't need to be told about `cat.tf` explicitly; it just picks up anything with a `.tf` extension.

## Common Naming Convention

Even though file names don't technically matter to Terraform, there's a widely-used convention for organizing a project:

| File | Purpose |
|---|---|
| `main.tf` | Where most resource definitions live |
| `variables.tf` | Input variables |
| `outputs.tf` | Outputs for the configuration |
| `providers.tf` | Provider configuration |

None of this is enforced by Terraform itself — it's purely for humans to keep a project readable as it grows. Put everything into one big `main.tf`, and once a project grows to 20+ resources, that file becomes a nightmare to scroll through and find anything in. Splitting it into `main.tf` / `variables.tf` / `outputs.tf` / `providers.tf` keeps each file focused on one job — anyone (including future-me) can open `variables.tf` and immediately know that's where all the inputs live, without hunting through hundreds of lines of resource blocks.

`variables.tf`, `outputs.tf`, and `providers.tf` will each get covered in more depth later on.

---
**Reference:** [Terraform Configuration — developer.hashicorp.com](https://developer.hashicorp.com/terraform/language)
