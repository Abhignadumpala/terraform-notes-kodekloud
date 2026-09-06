# Hands-On Lab: Lifecycle Rules

> Companion hands-on lab for [Module 5.3: Lifecycle Rules](../README.md). Lab not run yet — this note gets filled in once I've built and tested it.

---

## What I'm Planning to Build

Testing the three rules from the module note against real resources:

1. **`create_before_destroy`** on an EC2 instance — force a replacement (e.g. an AMI change) and confirm the new instance comes up before the old one is destroyed, instead of the default destroy-then-create.
2. **`prevent_destroy`** on a resource I don't want gone by accident — confirm Terraform refuses a plan that would destroy it, and that `terraform destroy` still overrides it.
3. **`ignore_changes`** on a tag — change the tag outside of Terraform (console or CLI), then confirm `terraform plan` no longer tries to revert it.

---

## Walking Through It

*Pending — will add the actual `.tf` code, commands, and screenshots here once the lab is run.*
