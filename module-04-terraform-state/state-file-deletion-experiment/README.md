# Experiment: What Happens If You Delete the State File?

> Related to [Module 04.2: Terraform State Considerations](../module-04.2-terraform-state-considerations/README.md#editing-the-state-file) — that note says state should be backed up because it's "genuinely hard to reconstruct if it's lost." I wanted to actually see what "hard to reconstruct" looks like, so I deleted it on purpose.

Ran this against the EC2 instance from the [Module 5.2 mutable-vs-immutable lab](../../module-05-working-with-terraform/module-05.2-mutable-vs-immutable-infrastructure/hands-on-lab/README.md), which was still up and running.

## The Question

**Does deleting `terraform.tfstate` and running `terraform plan` show drift, or does Terraform try to create the instance again?**

## What I Did

The instance `i-0292984e9644234f4` was running, tracked in state, tagged `web-server-v2`.

```bash
ls
# ec2_instance.tf  outputs.tf  provider.tf  terraform.tfstate  terraform.tfstate.backup

rm -r terraform.tfstate
rm -r terraform.tfstate.backup

ls
# ec2_instance.tf  outputs.tf  provider.tf   <- state and backup both gone

terraform plan
```

![Deleting terraform.tfstate and terraform.tfstate.backup, then running terraform plan](images/01-delete-state-file-and-plan.png)

## The Result: No Drift — Just a Fresh "Create"

With no state file, Terraform has nothing to compare the real world against. It doesn't know `i-0292984e9644234f4` exists at all. So the plan wasn't `~` (drift) or even `-/+` (replace) — it was a plain `+ create`, identical in shape to the very first `terraform apply` I ever ran against this config:

```
Terraform used the selected providers to generate the following execution plan.
Resource actions are indicated with the following symbols:
  + create

  # aws_instance.web_server will be created
  + resource "aws_instance" "web_server" {
      + ami           = "ami-0fb0b230890ccd1e6"
      + instance_type = "t2.micro"
      ...
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

![terraform plan summary - 1 to add, 0 to change, 0 to destroy](images/02-terraform-plan-create-summary.png)

I ran `terraform apply` to see it through:

![terraform apply repeating the same create plan](images/03-terraform-apply-create-plan.png)

```
aws_instance.web_server: Creating...
aws_instance.web_server: Creation complete after 14s [id=i-0b27b7db8bc982f02]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

instance_id        = "i-0b27b7db8bc982f02"
instance_public_ip = "98.92.145.55"
```

![terraform apply complete - new instance i-0b27b7db8bc982f02 created](images/04-terraform-apply-create-complete.png)

## The Actual Damage

The EC2 console now shows **two running instances**, both tagged `web-server-v2`:

| Instance ID | State | Notes |
|---|---|---|
| `i-0292984e9644234f4` | Running | The original — still alive, but no longer in Terraform's state |
| `i-0b27b7db8bc982f02` | Running | The new one Terraform just created and is now tracking |

![AWS console showing two running instances, both named web-server-v2](images/05-aws-console-duplicate-instances.png)

The new state file only knows about the new instance:

![AWS console - new instance i-0b27b7db8bc982f02, now the one Terraform tracks](images/06-aws-console-new-instance-tracked.png)

The old one, `i-0292984e9644234f4`, is now **orphaned** — it's real, it's billable, and `terraform destroy` will never touch it, because as far as Terraform's state is concerned it doesn't exist. Getting it back under management would need `terraform import`, or it just gets cleaned up by hand from the console.

Proof the new state is now self-consistent — running `terraform apply` again against the *new* instance shows no changes:

```
aws_instance.web_server: Refreshing state... [id=i-0b27b7db8bc982f02]

No changes. Your infrastructure matches the configuration.

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

![terraform apply after recreate - No changes, infrastructure matches configuration](images/07-terraform-apply-no-changes-after-recreate.png)

## Takeaway

Deleting state doesn't make Terraform "notice" anything is missing — it makes Terraform **forget the real infrastructure exists at all**. `plan`/`apply` fall back to their only other job: making reality match config, which here meant building a second copy from scratch. Drift detection depends entirely on state being present and accurate; with no state, there's nothing to detect drift *against*.

This is the concrete version of [Module 04.2](../module-04.2-terraform-state-considerations/README.md)'s "back up state files regularly" advice — the failure mode isn't a scary error message, it's a silently duplicated, silently orphaned, silently billable resource.
