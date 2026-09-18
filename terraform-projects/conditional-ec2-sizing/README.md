# Conditional EC2 Sizing

> One resource block, sized differently per environment: `t2.micro` for dev, `t2.medium` for prod — driven entirely by Terraform's conditional (ternary) expression.

---

## What This Project Is

A small, standalone Terraform project — not tied to a specific course lesson — built around one HCL feature that comes up constantly in real environments and in interviews: **conditional expressions**.

```hcl
condition ? true_val : false_val
```

Here, that's:

```hcl
instance_type = var.environment == "prod" ? "t2.medium" : "t2.micro"
```

Pass `environment = "prod"` and the instance comes up as `t2.medium`. Pass anything else (`"dev"`, `"staging"`, …) and it comes up as `t2.micro`. Same resource block, same `.tf` files — the only thing that changes between environments is which `.tfvars` file I point at.

---

## Project Structure

```
conditional-ec2-sizing/
├── provider.tf       # AWS provider + version constraints
├── data.tf           # aws_ami lookup - fresh AMI at apply time, no hardcoded ID
├── variables.tf       # environment, instance_name
├── ec2_instance.tf     # the aws_instance resource with the conditional
├── outputs.tf          # instance_id, instance_type, environment
├── dev.tfvars          # environment = "dev"
└── prod.tfvars         # environment = "prod"
```

The AMI is looked up through an `aws_ami` data source rather than a hardcoded AMI ID — hardcoded IDs are region-specific and go stale as AWS deprecates old AMIs, so the lookup keeps this runnable regardless of which region I point it at.

---

## Running It

```bash
cd conditional-ec2-sizing
terraform init
```

**Dev:**
```bash
terraform plan --var-file=dev.tfvars    # instance_type = "t2.micro"
terraform apply --var-file=dev.tfvars
terraform output                        # confirm instance_type is t2.micro
terraform destroy --var-file=dev.tfvars
```

**Prod:**
```bash
terraform plan --var-file=prod.tfvars   # instance_type = "t2.medium"
terraform apply --var-file=prod.tfvars
terraform output                        # confirm instance_type is t2.medium
terraform destroy --var-file=prod.tfvars
```

---

## Troubleshooting

| Issue | Fix |
|---|---|
| `error validating provider credentials` | Run `aws configure` first — needs a working access key + secret |
| AMI-related errors | Confirm `provider.tf`'s `region` actually has Amazon Linux 2 available (most regions do) |
| Can't destroy / instance limit errors | Only one environment should be up at a time — `terraform destroy --var-file=<env>.tfvars` the one that's running before starting the other |

---

## Taking It Further

Past one or two attributes, stacking more ternaries on the resource gets repetitive. A **locals map keyed by environment** scales better:

```hcl
locals {
  instance_config = {
    dev  = { type = "t2.micro", count = 1, monitoring = false }
    prod = { type = "t2.medium", count = 3, monitoring = true }
  }
  config = local.instance_config[var.environment]
}

resource "aws_instance" "app" {
  count         = local.config.count
  instance_type = local.config.type
  monitoring    = local.config.monitoring
  # ...
}
```

One lookup (`local.instance_config[var.environment]`) instead of three separate conditionals — `type`, `count`, and `monitoring` all come from the same map, and adding a new environment or a new setting means editing the map, not the resource block.

---

## What This Confirms

Running both environments back to back: `terraform plan` against `dev.tfvars` shows `t2.micro`, the same plan against `prod.tfvars` shows `t2.medium` — identical `.tf` files, identical `terraform apply` command, only the var file differs. That's the actual value of a conditional expression: the branching logic lives once, inside the resource block, instead of duplicated across environment-specific copies of the same file.
