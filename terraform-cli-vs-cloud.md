# Terraform CLI vs Terraform Cloud

**Course:** KodeKloud — Terraform
**Related to:** Class 3 (Why Terraform)

---

## Terraform CLI (what I've been using)

- Runs entirely on my own machine
- State file (`terraform.tfstate`) lives locally on disk, unless I configure a remote backend myself (like S3)
- I run `init`, `plan`, `apply` manually, every time
- No built-in collaboration — if a teammate also runs `apply` at the same time, this can cause state conflicts/corruption
- Free, open source

---

## Terraform Cloud (HashiCorp's hosted platform)

A managed service that runs Terraform *for* me, in the cloud, instead of on my own laptop.

- **Remote state storage** — the state file lives on HashiCorp's servers, not my machine, with locking to prevent two people applying at once
- **Remote execution** — `plan`/`apply` can run on HashiCorp's infrastructure instead of locally (useful for CI/CD, or so nobody needs AWS credentials sitting on their own laptop)
- **Team collaboration features** — access controls, approval workflows (someone reviews `plan` output before `apply` actually runs), audit history
- **VCS integration** — connect a GitHub repo, and it auto-triggers `plan` on every pull request
- Free tier available for individuals/small teams, paid tiers for larger orgs

---

## Side-by-Side Comparison

| | Terraform CLI | Terraform Cloud |
|---|---|---|
| Where it runs | My own machine | HashiCorp's servers |
| State storage | Local file (unless I set up a remote backend) | Built-in remote state, automatically |
| Collaboration | Manual coordination needed | Built-in locking, approvals, team access |
| Cost | Free | Free tier + paid tiers |
| Best for | Solo learning, small personal projects | Teams, production workflows |

---

## Where This Fits

Everything I've practiced so far (Day 1, Day 2 of TerraWeek, and this KodeKloud course) uses plain **Terraform CLI** — which is exactly right for solo learning and personal projects. Terraform Cloud/Enterprise becomes relevant once working with a team, or wanting CI/CD-driven deployments without keeping AWS credentials on a personal laptop.
