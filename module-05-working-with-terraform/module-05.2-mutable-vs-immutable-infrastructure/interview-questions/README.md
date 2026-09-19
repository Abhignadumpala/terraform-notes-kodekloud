# Interview Questions: Mutable vs Immutable Infrastructure

Based on [Module 5.2](../README.md) and the [hands-on lab](../hands-on-lab/README.md).

---

**1. You've deployed a t2.medium EC2 instance with Terraform. The requirement is to downgrade it to t2.micro without downtime. How would you do it?**

Not by just changing `instance_type` in the config and running `terraform apply` — that's an in-place update by default (AWS stops the instance, resizes it, starts it back up with the same ID), and "in-place" doesn't mean "no downtime": the instance is offline for however long that stop/start takes. It also keeps whatever state built up on that instance, instead of giving you a clean box.

So instead I'd force a replacement: create the t2.micro instance first, confirm it's healthy, only then remove the t2.medium one. That needs the instance sitting behind something that can shift traffic to the new instance once it's up — an ALB target group, an ASG, or a DNS record — since Terraform itself only controls create/destroy order, not traffic routing.

**1a. How do you actually force that in Terraform?**

Two things together:

```hcl
resource "aws_instance" "app" {
  ami           = "ami-xxxxx"
  instance_type = "t2.micro"

  lifecycle {
    create_before_destroy = true
  }
}
```

```bash
terraform apply -replace="aws_instance.app"
```

`-replace` tells Terraform to treat this resource as needing replacement even though nothing in the config forces it (`instance_type` isn't ForceNew — see the [ForceNew note in Module 5.2](../README.md)). `create_before_destroy` then controls the order: new instance created and confirmed up before the old one is destroyed, instead of Terraform's default destroy-then-create.

**1b. Does `create_before_destroy` alone give you zero downtime, or is there a catch?**

There's a catch: `create_before_destroy` only decides the *order* Terraform creates/destroys in. It doesn't move traffic. For a standalone instance with nothing in front of it, "new instance up before old one's destroyed" doesn't help anyone reach it unless something else routes traffic to the new one — an ALB target group, an ASG, or a DNS record that gets updated. So this pattern is really only zero-downtime when the instance already sits behind something that can shift traffic; on its own it just avoids a window with *no* instance running.

**1c. Concretely, when the new instance comes up, how does the ALB find out about it — is target group registration something you update manually?**

No, it's Terraform-managed, not a console click. You attach the instance to the target group with `aws_lb_target_group_attachment`, referencing the instance's id:

```hcl
resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app.id
  port             = 80

  lifecycle {
    create_before_destroy = true
  }
}
```

Because `target_id` points at `aws_instance.app.id`, replacing the instance forces this attachment to be replaced too — `target_id` has no update path, it's ForceNew on `aws_lb_target_group_attachment`. That replacement is automatic, driven by Terraform's dependency graph, not something anyone clicks through in the AWS console.

The part that's easy to miss: `create_before_destroy` on the instance alone isn't enough. The attachment depends on the instance, so it needs `create_before_destroy = true` too — otherwise Terraform can't guarantee the new attachment gets created before the old attachment (and old instance) are torn down, and you either get a dependency error on `terraform apply` or a real gap where the ALB has no target at all.

Even with `create_before_destroy` set correctly on both resources, two more things gate actual zero downtime — and neither one is something that flag handles:

- **Health checks.** The ALB won't send traffic to the new target until it passes the target group's health check (interval × healthy threshold). So "new instance exists" and "new instance is receiving traffic" aren't the same moment — there's a short window in between where the new instance is up but idle.
- **Connection draining** (`deregistration_delay` on the target group). When the old target is deregistered, the ALB keeps routing its *already in-flight* connections to it for that delay, so in-progress requests aren't cut off the instant Terraform tears the old instance down.

In practice, wiring this by hand with a single `aws_instance` + `aws_lb_target_group_attachment` works, but it's fiddly to get exactly right — you have to remember `create_before_destroy` on every resource in the dependency chain. That's the real reason production setups usually don't do it this way: an Auto Scaling Group with a target group attached handles the health-check gating and connection draining for you as part of an instance refresh, instead of hand-propagating `create_before_destroy` across resources.

**1d. When would you skip all this and let the default in-place resize happen?**

Dev/test environments, or anywhere a short stop/start is acceptable and you don't care about a clean slate — it's simpler and faster than standing up replacement infrastructure just to change an instance size.
