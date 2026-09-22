# Hands-On Lab: AWS EC2 with Terraform

> Companion hands-on lab for [Module 8.3: AWS EC2 with Terraform](../README.md). An Ubuntu instance, a Terraform-generated SSH key pair, a security group with explicit ingress/egress rules — deployed for real, then actually SSHed into to confirm nginx is running.

---

## What I Built

- **`data.aws_ami.ubuntu`** — most-recent Ubuntu 24.04 (Noble) LTS from Canonical, resolved fresh at apply time.
- **`aws_instance.webserver`** — `t3.micro`, `user_data` installs and starts nginx on first boot.
- **`tls_private_key.web` + `aws_key_pair.web`** — key pair generated entirely by Terraform, no pre-existing local key file needed.
- **`aws_security_group.ssh_access`** + **`aws_vpc_security_group_ingress_rule.ssh`** (port 22, `0.0.0.0/0`) + **`aws_vpc_security_group_egress_rule.all`** (all outbound) — separate rule resources, not inline blocks.

---

## Walking Through It

### 1. Apply

```bash
terraform init && terraform apply
```

```
aws_security_group.ssh_access: Creating...
tls_private_key.web: Creation complete after 1s [id=a02ed0f0e6866ef2172b0fd147be27e7092db2b8]
aws_key_pair.web: Creation complete after 1s [id=module-08-webserver-key]
aws_security_group.ssh_access: Creation complete after 3s [id=sg-043bab97fc96601c7]
aws_vpc_security_group_ingress_rule.ssh: Creation complete after 1s [id=sgr-01297bfd1fa072711]
aws_vpc_security_group_egress_rule.all: Creation complete after 1s [id=sgr-0597b519240e4b039]
aws_instance.webserver: Creation complete after 15s [id=i-0bb21ab75bdc3a440]

Apply complete! Resources: 6 added, 0 changed, 0 destroyed.

Outputs:
ami_id_used = "ami-025d99823a4caad37"
public_ip = "3.80.159.2"
ssh_private_key = <sensitive>
```

The `aws_ami` data source resolved to a real, current AMI ID at apply time — not the module note's `data "aws_ami"` example text, an actual ID Canonical published.

### 2. Get the private key out and SSH in

```bash
terraform output -raw ssh_private_key > web.pem
chmod 600 web.pem
ssh -i web.pem ubuntu@$(terraform output -raw public_ip)
```

First attempt, right after `apply` finished:

```
$ ssh -i web.pem ubuntu@3.80.159.2 "systemctl is-active nginx"
inactive
```

`nginx -v` confirmed the package was already installed at that point — `user_data` was still mid-run. Polled every 10 seconds:

```
attempt 1: nginx=active
```

Came up within the first poll after the initial check — `user_data` (apt update, install, enable, start) finished in well under a minute total. `cloud-init`'s own log confirmed it directly:

```
Setting up nginx (1.24.0-2ubuntu7.18) ...
Synchronizing state of nginx.service with SysV service script...
Cloud-init v. 26.1-0ubuntu1~24.04.1 finished at Tue, 22 Sep 2026 23:16:34 +0000. Up 41.72 seconds
```

### 3. Confirm nginx is actually serving, from both sides

From inside the instance, over the same SSH session:

```bash
systemctl is-active nginx    # active
systemctl is-enabled nginx   # enabled
curl -s -o /dev/null -w 'HTTP %{http_code}\n' localhost   # HTTP 200
```

From outside — this sandbox, hitting the instance's public IP directly on port 80:

```bash
curl -s -o /dev/null -w 'HTTP %{http_code}\n' http://3.80.159.2/ --max-time 10
```

```
curl: (28) Connection timed out
```

**Expected, and correct** — the security group only ever opened port 22. Port 80 was never in scope for this lesson (it's about SSH access, not exposing a public webserver), and the timeout is proof the security group is doing exactly what it's configured to do: nginx runs, but only reachable from inside the instance itself unless a port-80 ingress rule gets added on top of this.

### 4. Independent confirmation via the AWS CLI

```bash
aws ec2 describe-instances --instance-ids i-0bb21ab75bdc3a440 \
  --query "Reservations[0].Instances[0].{State:State.Name,Type:InstanceType,AMI:ImageId,PublicIp:PublicIpAddress}"
```

```json
{
  "State": "running",
  "Type": "t3.micro",
  "AMI": "ami-025d99823a4caad37",
  "PublicIp": "3.80.159.2"
}
```

```bash
aws ec2 describe-security-groups --group-ids sg-043bab97fc96601c7 \
  --query "SecurityGroups[0].{IngressRules:IpPermissions,EgressRules:IpPermissionsEgress}"
```

Confirmed exactly one ingress rule (TCP 22, `0.0.0.0/0`) and one egress rule (all protocols, `0.0.0.0/0`) — nothing implicit, nothing extra, matching `main.tf` precisely.

### Clean up

```bash
terraform destroy -auto-approve
```

```
Destroy complete! Resources: 6 destroyed.
```

---

## Troubleshooting

| Issue | Fix |
|---|---|
| `nginx: inactive` right after `apply` | `user_data` runs asynchronously after boot — give it 30–60 seconds and re-check, or `ssh` in and `sudo tail -f /var/log/cloud-init-output.log` to watch it happen live |
| SSH connection refused/times out entirely | Check the security group actually has the port-22 ingress rule attached to this instance's SG, and that `key_name` on `aws_instance` actually points at the key pair the private key matches |
| `curl` to the public IP hangs / times out on port 80 | Expected in this lab — no port-80 ingress rule was ever created, only 22 |

---

## Summary

- **AMI resolved dynamically:** the `data "aws_ami"` block found a real, current Ubuntu 24.04 build (`ami-025d99823a4caad37`) at apply time, not a hardcoded ID.
- **Key pair generated in-Terraform:** `tls_private_key` + `aws_key_pair`, no pre-existing local file required — confirmed by actually retrieving the private key from state and using it to SSH in successfully.
- **nginx confirmed running, two ways:** `systemctl is-active` over SSH, and `curl localhost` returning `HTTP 200` from inside the instance.
- **Security group confirmed doing exactly its job:** port 22 open and working; port 80 correctly unreachable from outside, verified by a real timeout, not just by reading the HCL.

**Next up:** [Terraform Provisioners](../../module-08.4-terraform-provisioners/README.md) — running commands *inside* an instance like this one, from Terraform itself.
