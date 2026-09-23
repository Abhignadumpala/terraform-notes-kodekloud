# 📘 Module 8.1: Introduction to AWS EC2 (Optional)

> Module 8 is about Terraform provisioners — but provisioners run *inside* an instance once it exists, so I'm starting with the instance itself. Marking this one optional too — skip ahead if EC2 basics are already familiar.

---

## Introduction

**EC2 (Elastic Compute Cloud)** is AWS's virtual-machine service — scalable compute, deployable in minutes. Like any computer, physical or virtual, an EC2 instance runs an OS (a Linux distro, or Windows) and can host whatever runs on top of one: a database, a web server, an application server.

---

## AMIs: What an Instance Boots From

An **AMI (Amazon Machine Image)** is a pre-configured template — the OS plus whatever software configuration AWS (or whoever built it) baked in. Amazon Linux 2, Ubuntu 20.04, RHEL 8, Windows 2019 are all AMIs. Every AMI has an ID, and that ID is specific to the AWS region — the same Ubuntu AMI has a different ID in `us-east-1` than in `eu-west-1`.

---

## Instance Types: CPU, Memory, Networking

An instance type is a specific combination of vCPU, memory, and network performance, grouped into families for different workload shapes: general purpose for a balanced mix, compute-optimized for CPU-heavy batch/data-modeling work, memory-optimized for large in-memory datasets.

General purpose splits further into T3, T4g, M6i/M7i, and others, each in a range of sizes — nano/micro/small up through 2xlarge and beyond, roughly doubling vCPU and memory at each step:

![Table of General Purpose instance sizes (shown here as T2: t2.nano through t2.2xlarge) scaling from 1 vCPU/0.5 GB up to 8 vCPU/32 GB](images/01-t2-general-purpose-instance-types.png)

**T3** runs on the AWS Nitro hypervisor and is my default for general-purpose burstable workloads — `t3.micro` in particular, since it's the Free Tier size I reach for in this repo's own labs. **T4g** (Graviton/ARM-based) is the step up from T3 when the workload can run on ARM — better price-performance still, at the cost of needing an ARM-compatible AMI.

---

## EBS: Persistent Storage

**EBS (Elastic Block Store)** is EC2's persistent disk storage — chosen and sized at launch, with more volumes attachable later.

![Table of EBS volume types: io1 (SSD, business-critical apps), io2 (SSD, latency-sensitive transactional), gp2 (SSD, general purpose), st1 (HDD, throughput-intensive), sc1 (HDD, lowest-cost infrequent access)](images/02-ebs-volume-types.png)

EBS offers six volume types in total. Three SSD: `gp3` ([the default when none is specified](https://aws.amazon.com/ebs/volume-types/), decoupling IOPS and throughput from volume size, unlike `gp2`), `gp2`, and `io2`/`io1` for provisioned-IOPS, latency-sensitive workloads (`io2` for better durability at a comparable price). Two HDD: `st1` for throughput-heavy access, `sc1` for the lowest-cost, infrequent-access tier.

---

## User Data: Bootstrapping at Launch

**User data** is a script EC2 runs automatically on first boot — the mechanism for "install and start this software the moment the instance exists," instead of SSHing in afterward to do it by hand. For Linux, that's typically a bash script:

```bash
#!/bin/bash
sudo apt update
sudo apt install nginx -y
sudo systemctl enable nginx
sudo systemctl start nginx
```

Windows instances take the same idea via PowerShell or a `.bat` script instead.

![Diagram: a bash script installing/starting nginx feeds into an Ubuntu web server; a PowerShell/Batch script feeds into a Windows instance](images/03-user-data-linux-windows.png)

---

## Accessing an Instance

- **Linux** — SSH, using a key pair generated (or imported) at launch.
- **Windows** — RDP (Remote Desktop), using a username and a password AWS decrypts with that same key pair.

---

## Summary

- ✅ An AMI is the OS + software template an instance boots from; its ID is region-specific
- ✅ Instance types combine vCPU/memory/network performance into families (general purpose, compute-optimized, memory-optimized)
- ✅ T3 (Nitro hypervisor) is my default general-purpose choice, T4g the step up when ARM works for the workload
- ✅ EBS is the attachable, persistent disk layer — chosen and sized at launch
- ✅ Six EBS volume types: `gp3` (the default), `gp2`, `io2`/`io1` (SSD), `st1`/`sc1` (HDD)
- ✅ User data scripts run automatically on first boot — the way to bootstrap software without a manual SSH session afterward
- ✅ Linux → SSH with a key pair; Windows → RDP with a password decrypted by that key pair

---

## Key Takeaway

**An EC2 instance is AMI (what it boots) + instance type (what it runs on) + EBS (what it stores on) + user data (what it does on first boot) — four independent choices that together define the instance.**

- ✅ T3/T4g and `gp3` are my defaults on anything new
- ⚠️ User data only runs once, on first boot — it's a bootstrap mechanism, not a way to push ongoing configuration changes

---

## Practice & Next Steps

Look up the current general purpose instance types (T3, T3a, T4g, M6i/M7i) in the [AWS instance types docs](https://aws.amazon.com/ec2/instance-types/) and compare vCPU/memory/price across the family. Then move to [8.2: Demo Deploying an EC2 Instance](../module-08.2-demo-deploying-an-ec2-instance/README.md), and from there to [8.3: AWS EC2 with Terraform](../module-08.3-aws-ec2-with-terraform/README.md) — where this module's actual subject, provisioners, needs a running instance to provision.
