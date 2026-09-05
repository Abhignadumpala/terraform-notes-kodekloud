# Hands-On Lab: Mutable vs Immutable Infrastructure

> Companion hands-on lab for [Module 5.2: Mutable vs Immutable Infrastructure](../README.md). Code lives in [`mutable-vs-immutable-code/`](mutable-vs-immutable-code).

---

## What I Built

One EC2 instance, two different kinds of changes, to see the theory from the module notes actually happen on AWS:

1. Change a **tag** → mutable, in-place update (`~` in the plan, same instance ID).
2. Change the **AMI** → immutable, destroy-and-recreate (`-/+` in the plan, brand new instance ID).

**Why AMI and not instance type:** my first pass at this lab used `instance_type` (`t2.micro` → `t2.small`) as the "immutable" example. Wrong — `instance_type` is *not* a ForceNew attribute on `aws_instance`. Terraform just stops the instance, calls `ModifyInstanceAttribute`, and starts it back up with the same instance ID. `ami`, on the other hand, actually is ForceNew, so swapping it is the real destroy-and-recreate case — which is what I ran below.

Files: `provider.tf`, `ec2_instance.tf`, `outputs.tf`.

---

## Walking Through It

### 1. Reviewing the code before touching AWS

Two AMI data sources — Amazon Linux 2 (the starting AMI) and Ubuntu (the swap-to AMI for Part 2) — and one `aws_instance` starting on `t2.micro` with `Name = "web-server-v1"`.

![ec2_instance.tf before any changes](images/01-ec2-instance-tf-initial.png)

### 2. Deploy the baseline

```bash
terraform plan
terraform apply
```

`terraform plan` resolved the AMI data sources and showed everything as `+ create` for a new `t2.micro` instance:

![terraform plan showing full resource create](images/02-terraform-plan-create.png)

![terraform plan summary - 1 to add, 0 to change, 0 to destroy](images/03-terraform-plan-create-summary.png)

`terraform apply`, confirmed with `yes`:

![terraform apply create plan](images/04-terraform-apply-create.png)

Instance came up in 14s:

```
aws_instance.web_server: Creation complete after 14s [id=i-0b2662ef8fc8a1b9e]

current_ami         = "ami-002db1d61667182d2"
instance_id         = "i-0b2662ef8fc8a1b9e"
instance_public_ip  = "98.82.31.193"
instance_tags       = { Name = "web-server-v1", Environment = "lab", Project = "mutable-vs-immutable" }
```

![terraform apply create complete with outputs](images/05-terraform-apply-create-complete.png)

Confirmed in the AWS console — `i-0b2662ef8fc8a1b9e`, tagged `web-server-v1`:

![AWS console - instance i-0b2662ef8fc8a1b9e tagged web-server-v1](images/06-aws-console-instance-v1.png)

### 3. Part 1 — mutable change (tag)

Changed the tag in `ec2_instance.tf`:

![ec2_instance.tf - Name changed to web-server-v2](images/07-ec2-instance-tf-tag-v2.png)

```bash
terraform plan
```

Exactly the symbol I was testing for — `~ update in-place`, not `-/+`. The `id` field doesn't even show as changing:

```
Terraform will perform the following actions:
  # aws_instance.web_server will be updated in-place
  ~ resource "aws_instance" "web_server" {
        id   = "i-0b2662ef8fc8a1b9e"
      ~ tags = {
          ~ "Name" = "web-server-v1" -> "web-server-v2"
        }
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

![terraform plan - tag update in-place](images/08-terraform-plan-tag-update-in-place.png)

```bash
terraform apply
```

```
aws_instance.web_server: Modifying... [id=i-0b2662ef8fc8a1b9e]
aws_instance.web_server: Modifications complete after 3s [id=i-0b2662ef8fc8a1b9e]

Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

![terraform apply - tag modification in progress](images/09-terraform-apply-tag-update.png)

![terraform apply - tag update outputs, same instance ID](images/10-terraform-apply-tag-update-outputs.png)

Back in the AWS console: **same instance ID**, `i-0b2662ef8fc8a1b9e`, now tagged `web-server-v2`. Same public IP too — it never stopped running.

![AWS console - same instance ID i-0b2662ef8fc8a1b9e now tagged web-server-v2](images/11-aws-console-instance-v2-same-id.png)

### 4. Part 2 — immutable change (AMI)

Pointed the instance at the Ubuntu AMI instead of Amazon Linux 2:

![ec2_instance.tf - ami switched to data.aws_ami.ubuntu.id](images/12-ec2-instance-tf-ami-ubuntu.png)

```bash
terraform plan
```

Completely different symbol this time — `-/+ destroy and then create replacement`, `must be replaced`, and `ami` explicitly called out with `# forces replacement`:

```
# aws_instance.web_server must be replaced
-/+ resource "aws_instance" "web_server" {
      ~ ami = "ami-002db1d61667182d2" -> "ami-0fb0b230890ccd1e6" # forces replacement
      ~ id  = "i-0b2662ef8fc8a1b9e" -> (known after apply)
      ...
    }

Plan: 1 to add, 0 to change, 1 to destroy.
```

![terraform plan - AMI change forces replacement](images/13-terraform-plan-ami-replace.png)

![terraform plan summary - 1 to add, 0 to change, 1 to destroy](images/14-terraform-plan-ami-replace-summary.png)

```bash
terraform apply
```

![terraform apply - AMI replace plan](images/15-terraform-apply-ami-replace.png)

```
aws_instance.web_server: Destroying... [id=i-0b2662ef8fc8a1b9e]
aws_instance.web_server: Still destroying... [id=i-0b2662ef8fc8a1b9e, 00m30s elapsed]
aws_instance.web_server: Destruction complete after 31s

aws_instance.web_server: Creating...
aws_instance.web_server: Creation complete after 14s [id=i-0292984e9644234f4]

Apply complete! Resources: 1 added, 0 changed, 1 destroyed.

current_ami         = "ami-0fb0b230890ccd1e6"
instance_id         = "i-0292984e9644234f4"
instance_public_ip  = "44.195.59.234"
```

![terraform apply - old instance destroyed, new instance created](images/16-terraform-apply-ami-replace-complete.png)

Genuinely a different instance now: new ID (`i-0292984e9644234f4`, was `i-0b2662ef8fc8a1b9e`), new public IP (`44.195.59.234`, was `98.82.31.193`), new AMI. The old instance shows up in the console as **Terminated**:

![AWS console - old instance i-0b2662ef8fc8a1b9e now Terminated](images/17-aws-console-old-instance-terminated.png)

### 5. Clean up

```bash
terraform destroy
```

---

## What This Confirms

| | Tag change (Part 1) | AMI change (Part 2) |
|---|---|---|
| Plan symbol | `~` | `-/+` |
| Instance ID | `i-0b2662ef8fc8a1b9e` both times | `i-0b2662ef8fc8a1b9e` → `i-0292984e9644234f4` |
| Public IP | `98.82.31.193` both times | `98.82.31.193` → `44.195.59.234` |
| Action | Modify | Destroy & Create |
| Downtime | none | ~31s destroy + 14s create, unless I add `create_before_destroy` |

Matches what [Module 5.2](../README.md) says: Terraform isn't purely mutable or purely immutable — it picks per-attribute, based on whether the provider marks that attribute as ForceNew. Tags aren't ForceNew. `ami` is. `instance_type` isn't (a common assumption I got wrong the first time around, before actually running this).

**Optional follow-up:** add `lifecycle { create_before_destroy = true }` to the resource, re-run the AMI change, and watch the plan create the new instance *before* destroying the old one instead of after.
