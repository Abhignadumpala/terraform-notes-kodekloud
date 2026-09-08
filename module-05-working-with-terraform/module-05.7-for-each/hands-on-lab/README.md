# Hands-On Lab: for_each

> Companion hands-on lab for [Module 5.7: for_each](../README.md). Code lives in [`for-each-code/`](for-each-code) — this is what you actually run locally (`cd` into that folder and use standard `terraform init`/`plan`/`apply`).

---

## What I Built

The same 3 servers as the [Module 5.6 count lab](../../module-05.6-count/hands-on-lab/README.md), rebuilt with `for_each` instead of `count` — so the two labs can be compared directly:

- **`variables.tf`** — `web_server_names`, now typed `set(string)` (not `list(string)`) since `for_each` won't accept a plain list.
- **`ec2_instances.tf`** — `aws_instance.web`, `for_each = var.web_server_names`, each instance tagged `Name = each.value`. No `count.index` anywhere.
- **`data.tf`** — the same Ubuntu AMI datasource pattern as the other Module 5 labs.
- **`outputs.tf`** — instance IDs keyed by name (a map, not a list), and one instance referenced directly by key (`aws_instance.web["web-prod-2"]`).

The point of this lab is the opposite of 5.6's: remove a name from the set and confirm that *only* the matching instance is touched — no shifting, no surprise deletions.

Files: `provider.tf`, `data.tf`, `variables.tf`, `ec2_instances.tf`, `outputs.tf`.

---

## Walking Through It

### 1. Deploy the baseline

```bash
cd for-each-code
terraform init
terraform plan
```

Expect a plain `+ create` for all 3, keyed by name instead of index:

```
# aws_instance.web["web-prod-1"] will be created
# aws_instance.web["web-prod-2"] will be created
# aws_instance.web["web-prod-3"] will be created

Plan: 3 to add, 0 to change, 0 to destroy.
```

```bash
terraform apply
```

Check the outputs and the AWS console — 3 running instances, same as 5.6's baseline, just addressed by name in the plan/state instead of `[0]`/`[1]`/`[2]`.

### 2. Remove an element and confirm nothing shifts

Edit `variables.tf` and remove `"web-prod-1"` from the set:

```hcl
variable "web_server_names" {
  # ...
  default = ["web-prod-2", "web-prod-3"] # was ["web-prod-1", "web-prod-2", "web-prod-3"]
}
```

```bash
terraform plan
```

Expect exactly one line of change:

```
# aws_instance.web["web-prod-1"] will be destroyed

Plan: 0 to add, 0 to change, 1 to destroy.
```

`web-prod-2` and `web-prod-3` shouldn't appear in the plan at all — their keys never changed. Compare this directly against [Module 5.6's plan output](../../module-05.6-count/hands-on-lab/README.md) for the identical change (`2 to change, 1 to destroy`, and the wrong instance ending up deleted).

### 3. Apply it and confirm in the console

```bash
terraform apply
```

Watch the log: only `aws_instance.web["web-prod-1"]` gets destroyed. `web-prod-2` and `web-prod-3` keep their original instance IDs and are never mentioned in the apply log at all. Confirm in the AWS console that the two remaining instances are still `web-prod-2` and `web-prod-3` — not renamed, not recreated.

### 4. (Optional) Try removing a name from the middle instead of the end

Repeat step 2, but this time delete `"web-prod-2"` (the middle one) instead of the first. With `count`, removing a middle element is exactly as disruptive as removing the first — everything after it still shifts. With `for_each`, it shouldn't matter where in the set the removed name was; only that one key's instance should show up in the plan. Worth confirming for yourself since it's easy to assume "removing the first item is the special case."

### 5. Clean up

```bash
terraform destroy
```

---

## What This Confirms

*Pending — will fill in with real plan/apply output and screenshots once I run through the steps above.*
