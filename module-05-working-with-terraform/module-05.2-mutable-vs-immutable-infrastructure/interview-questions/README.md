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

**1c. When would you skip all this and let the default in-place resize happen?**

Dev/test environments, or anywhere a short stop/start is acceptable and you don't care about a clean slate — it's simpler and faster than standing up replacement infrastructure just to change an instance size.
