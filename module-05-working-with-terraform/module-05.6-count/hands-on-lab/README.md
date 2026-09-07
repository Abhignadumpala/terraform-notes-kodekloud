# Hands-On Lab: Count

> Companion hands-on lab for [Module 5.6: Count](../README.md). Code lives in [`count-code/`](count-code) — this is what you actually run locally (`cd` into that folder and use standard `terraform init`/`plan`/`apply`).

---

## What I Built

One `aws_instance` block with `count = length(var.web_server_names)`, so the number of instances — and their names — comes entirely from `variables.tf`:

- **`variables.tf`** — `web_server_names`, a list of 3 names (`web-prod-1`, `web-prod-2`, `web-prod-3`).
- **`ec2_instances.tf`** — `aws_instance.web`, `count` driven by `length(var.web_server_names)`, each instance tagged `Name = var.web_server_names[count.index]`.
- **`data.tf`** — the same Ubuntu AMI datasource pattern from the [05.3](../../module-05.3-lifecycle-rules/hands-on-lab/README.md) and [05.4](../../module-05.4-datasources/README.md) labs.
- **`outputs.tf`** — all instance IDs (`[*]`), a map of index → name, and one specific instance (`[0]`).

The point of this lab isn't the instances themselves — it's what happens to their *indices* when the list they're generated from changes.

Files: `provider.tf`, `data.tf`, `variables.tf`, `ec2_instances.tf`, `outputs.tf`.

---

## Walking Through It (to run)

### 1. Deploy the baseline

```bash
cd count-code
terraform init
terraform apply
```

This creates 3 instances — `aws_instance.web[0]` (`web-prod-1`), `web[1]` (`web-prod-2`), `web[2]` (`web-prod-3`). Check the outputs and the AWS console to confirm all three came up with the right names.

### 2. Trigger the index-shifting pitfall

Edit `variables.tf` and remove the **first** element from the default list:

```hcl
variable "web_server_names" {
  # ...
  default = ["web-prod-2", "web-prod-3"] # was ["web-prod-1", "web-prod-2", "web-prod-3"]
}
```

```bash
terraform plan
```

Expect **not** a clean "1 to destroy." Instead, look for:
- `aws_instance.web[0]` — `must be replaced` (its `Name` tag moves from `web-prod-1` to `web-prod-2`)
- `aws_instance.web[1]` — `must be replaced` (its `Name` tag moves from `web-prod-2` to `web-prod-3`)
- `aws_instance.web[2]` — `will be destroyed`

Three resources touched, for what should have been a one-instance removal. This is the pitfall from the [module notes](../README.md#️-the-pitfall-index-shifting) happening for real.

### 3. (Optional) Apply it and watch the churn

```bash
terraform apply
```

Watch the log: `web[0]` and `web[1]` actually get destroyed-and-recreated (new instance IDs both times), and `web[2]` is destroyed outright. Only one name was removed from the list, but every instance after it got touched.

### 4. Clean up

```bash
terraform destroy
```

---

## What This Confirms

*Pending — will fill in with real plan/apply output and screenshots once I run through the steps above.*
