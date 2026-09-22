# Hands-On Lab: Cross-Stack State Sharing

> Companion hands-on lab for [Module 7.2: Cross-Stack State Sharing](../README.md). Three separate Terraform configs — `bootstrap/`, `network/`, `compute/` — each its own state, wired together with a shared S3 backend and `terraform_remote_state`.

---

## What I Built

- **`bootstrap/`** — one S3 bucket (`tf-remote-state-lab-<random>`), versioned, encrypted, public access blocked. Local state, applied once, exists only to create the shared backend the other two stacks point at.
- **`network/`** — a VPC, public subnet, internet gateway + route table, and a security group. Its own state, in the bootstrap bucket at key `network/terraform.tfstate`.
- **`compute/`** — one EC2 instance, no networking resources declared at all. Reads `subnet_id` and `security_group_id` from `network/`'s state via `data "terraform_remote_state"`. Its own state, same bucket, key `compute/terraform.tfstate`.

Three independent `terraform init`/`plan`/`apply` cycles, three separate state files, one shared bucket.

---

## Walking Through It

### 1. Bootstrap the shared backend

```bash
cd bootstrap && terraform apply
```

```
random_id.suffix: Creation complete after 0s [id=lQYhTQ]
aws_s3_bucket.state: Creation complete after 3s [id=tf-remote-state-lab-9506214d]
aws_s3_bucket_public_access_block.state: Creation complete after 0s [id=tf-remote-state-lab-9506214d]
aws_s3_bucket_server_side_encryption_configuration.state: Creation complete after 1s [id=tf-remote-state-lab-9506214d]
aws_s3_bucket_versioning.state: Creation complete after 2s [id=tf-remote-state-lab-9506214d]

Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

Outputs:
state_bucket_name = "tf-remote-state-lab-9506214d"
```

That bucket name goes into both `network/provider.tf` and `compute/provider.tf`'s `backend "s3"` blocks by hand — same limitation [4.2](../../../module-04-terraform-state/module-04.2-terraform-state-considerations/README.md) already found: a backend block can't reference another config's output directly, only a literal value.

### 2. Apply the network stack

```bash
cd network && terraform init && terraform apply
```

```
aws_vpc.main: Creation complete after 14s [id=vpc-0810399a165e9bfe6]
aws_internet_gateway.main: Creation complete after 1s [id=igw-011069c85ec9bb3f6]
aws_route_table.public: Creation complete after 2s [id=rtb-06a7ff6da66dd0503]
aws_security_group.web: Creation complete after 4s [id=sg-0c8e7389d4e8697e5]
aws_subnet.public: Creation complete after 12s [id=subnet-0c43a0a14adf2e377]
aws_route_table_association.public: Creation complete after 0s [id=rtbassoc-08914dd97c64d35d0]

Apply complete! Resources: 6 added, 0 changed, 0 destroyed.

Outputs:
security_group_id = "sg-0c8e7389d4e8697e5"
subnet_id = "subnet-0c43a0a14adf2e377"
vpc_id = "vpc-0810399a165e9bfe6"
```

Checked the bucket right after — just the state file, no lock file. Locks in S3 only exist while an operation is actively running; they get deleted the moment `apply` finishes.

### 3. Catch the lock file live, and resolve 7.1's open question

To actually see the `.tflock` file, I ran `compute/`'s apply in the background and polled the bucket every second while it ran:

```bash
terraform apply -auto-approve > /tmp/compute-apply.log 2>&1 &
for i in 1 2 3 4 5 6 7 8; do sleep 1; aws s3 ls s3://tf-remote-state-lab-9506214d/ --recursive; done
```

```
compute/terraform.tfstate.tflock
network/terraform.tfstate
```

**On Terraform 1.16.1, the lock file is exactly `<key>.tflock`** — matching [7.1](../module-07.1-s3-remote-backend-and-locking/README.md#native-locking-version-history-and-the-lock-file-name)'s current-docs description, not [4.2](../../../module-04-terraform-state/module-04.2-terraform-state-considerations/README.md)'s `.terraform.lock.terraform`. That earlier mismatch looks like it was a version-specific quirk (likely from whatever CLI version 4.2's lab was originally run against) that no longer reproduces on a current release — worth re-checking against whatever version is actually installed rather than assuming either note is permanently right.

### 4. Apply the compute stack, and confirm the cross-stack wiring actually worked

```
aws_instance.app: Creation complete after 15s [id=i-0cf3883647ef849af]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:
instance_id = "i-0cf3883647ef849af"
instance_public_ip = "107.23.142.66"
vpc_id_from_remote_state = "vpc-0810399a165e9bfe6"
```

`vpc_id_from_remote_state` matches `network/`'s own `vpc_id` output exactly — `compute/main.tf` never declares a VPC, subnet, or security group anywhere in its own code; every one of those IDs came from `data.terraform_remote_state.network.outputs`.

Confirmed independently with the AWS CLI, checking the actual instance rather than trusting Terraform's own output:

```bash
aws ec2 describe-instances --instance-ids i-0cf3883647ef849af \
  --query "Reservations[0].Instances[0].{State:State.Name,SubnetId:SubnetId,VpcId:VpcId,SecurityGroups:SecurityGroups[0].GroupId}"
```

```json
{
  "State": "running",
  "SubnetId": "subnet-0c43a0a14adf2e377",
  "VpcId": "vpc-0810399a165e9bfe6",
  "SecurityGroups": "sg-0c8e7389d4e8697e5"
}
```

Every ID matches `network/`'s outputs exactly — the instance really did land in the subnet and security group the network stack created, with zero networking code in `compute/`.

### Clean up

Destroyed in dependency order — `compute` first (it depends on `network`), then `network`, then `bootstrap` last (needed `force_destroy = true` temporarily, since the bucket's versioning had kept every revision of both state files):

```bash
cd compute   && terraform destroy -auto-approve   # EC2 instance
cd network   && terraform destroy -auto-approve   # VPC, subnet, security group, etc.
cd bootstrap && terraform apply -auto-approve      # add force_destroy = true first
cd bootstrap && terraform destroy -auto-approve    # the bucket itself
```

---

## Troubleshooting

| Issue | Fix |
|---|---|
| `NoSuchBucket` on `network`/`compute` init | The bucket name in `provider.tf`'s `backend "s3"` block is stale — re-run `bootstrap`, copy its fresh `state_bucket_name` output into both other stacks |
| `data.terraform_remote_state.network.outputs.subnet_id` is null | `network/` hasn't been applied yet, or its `key` in `compute/main.tf`'s `terraform_remote_state` block doesn't match what `network/provider.tf`'s backend actually wrote to |
| `BucketNotEmpty` destroying the bootstrap bucket | Versioning kept every revision of `network/terraform.tfstate` and `compute/terraform.tfstate` — add `force_destroy = true` to `aws_s3_bucket.state`, `apply`, then `destroy` |

---

## Summary

- **Three stacks, one bucket:** `bootstrap` creates it, `network` and `compute` each get their own key inside it via `backend "s3"`.
- **Zero duplicated resources:** `compute/` never declares a VPC, subnet, or security group — it reads all three from `network/`'s state.
- **Verified two ways:** Terraform's own `vpc_id_from_remote_state` output, and an independent `aws ec2 describe-instances` call confirming the real instance landed in the real subnet/security group.
- **Resolved 7.1's open question for real:** on Terraform 1.16.1, the S3 lock file is `<key>.tflock`, caught live mid-`apply` — the naming mismatch 4.2 documented doesn't reproduce on this version.

**Next up:** that wraps Module 7 — remote backends in 7.1, cross-stack sharing here in 7.2.
