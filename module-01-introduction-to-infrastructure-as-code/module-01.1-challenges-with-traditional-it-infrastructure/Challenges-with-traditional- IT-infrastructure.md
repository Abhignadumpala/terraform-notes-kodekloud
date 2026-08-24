# 1.1 — Challenges with Traditional IT Infrastructure (Traditional IT vs Cloud vs IaC)

**Course:** KodeKloud — Terraform
**Class:** 1

---

## The Traditional IT Request Chain

<img width="1595" height="903" alt="image" src="https://github.com/user-attachments/assets/a842d55a-49fa-4d14-b12b-d8093a829dca" />


Before cloud computing, getting a single server provisioned meant passing through a long chain of people and approvals — often taking **weeks to months**.

### The approval chain

```
Business → Business Analyst → Solution Architect / Technical Lead → Procurement
```

Every infrastructure request first has to pass through this chain *before* any technical work even begins.

### The infrastructure team chain

Once procurement approves the request, it moves through the **Infrastructure Team** — itself another sequence of handoffs:

```
Field Engineers → System/Network Admins → Storage Admins → Backup Admins → Application Team
```

Each handoff between teams involves waiting — a ticket sitting in a queue, an approval, a scheduling conflict. All of this eventually results in physical hardware being racked in a **data center** (VMware, physical servers, storage arrays, backup systems).

---

## Traditional IT — Pain Points

| Problem | Why it happens |
|---|---|
| **Slow deployment** | Every handoff between teams adds days or weeks of waiting |
| **Expensive** | Physical servers/storage must be bought upfront, whether needed yet or not |
| **Limited automation** | Manual handoffs between specialized teams — nothing is self-service |
| **Human error** | More people touching the process = more chances for mistakes |
| **Wasted resources** | Companies over-provision hardware "just in case," since buying more later takes weeks |
| **Inconsistency** | Different admins configure things slightly differently each time — no standardization |

**Bottom line:** getting a single server provisioned the traditional way could take weeks to months — procurement alone often took longer than the actual technical setup.

---

## How Cloud Solved This

Cloud providers (AWS, Azure, GCP) collapsed the entire chain — Business → Procurement → 5 different admin teams → data center — into a **self-service web console or API** that takes minutes, not weeks.

### Example: launching an EC2 instance (AWS Console)

<img width="1600" height="829" alt="image" src="https://github.com/user-attachments/assets/51034948-8bf1-4584-86b7-c6cdfdeb5992" />


The traditional multi-team, multi-week process becomes a 7-step wizard anyone can complete themselves:

1. Choose AMI (the operating system)
2. Choose instance type (e.g. `t2.micro` — free tier eligible)
3. Configure instance
4. Add storage
5. Add tags
6. Configure security group
7. Review and launch

No procurement ticket. No waiting on five different admin teams. No physical hardware to buy.

### What actually changed

| Traditional | Cloud |
|---|---|
| Buy physical hardware upfront | Pay only for what you use, by the hour/second |
| Weeks of procurement + provisioning | Minutes — self-service, click "Launch" |
| Separate specialized admin teams (network/storage/backup) | One person (or one script) manages it all through an API |
| Manual, inconsistent setup each time | Same configuration every time |
| Guess capacity needs, often over-provision | Scale up or down on demand |

---

## The Next Step Beyond the Console

Even the cloud console wizard shown above still involves manually clicking through 7 screens each time. This is exactly the gap **Infrastructure as Code** (Terraform, CloudFormation, CDK) closes:

- Instead of clicking through a wizard, the same EC2 instance is described in a config file
- Running it is instant, repeatable, and version-controlled in Git
- No manual re-clicking through the same steps for the next environment (dev, staging, prod)

**Progression to keep in mind:**
```
Traditional IT (weeks, many teams)
        ↓
Cloud console (minutes, self-service, but still manual clicking)
        ↓
Infrastructure as Code (seconds, automated, repeatable, version-controlled)
```

---

## Key Takeaway

Cloud computing didn't just make infrastructure faster — it collapsed an entire organizational chain of people, approvals, and physical procurement into a self-service model. Terraform (and other IaC tools) then remove the last remaining manual step — clicking through a console — entirely. This is the "why" behind the rest of this course: everything from here on is about *how* Terraform actually does that.

---

**Next up:** Class 2
