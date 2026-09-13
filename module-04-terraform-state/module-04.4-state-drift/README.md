# 📘 Module 4.4: State Drift

> What happens when the real infrastructure quietly stops matching my config and state — how `terraform plan` catches it, and the two different ways to fix it depending on which side was actually "right."

---

## Introduction

[Module 4.1](../module-04.1-purpose-of-state/README.md) covered why the state file exists at all — it's what maps my config to one specific real resource. This note is about what happens when that mapping goes stale: when someone (or something) changes the real resource *outside* Terraform, and my config, my state, and reality stop agreeing with each other. That's called **drift**.

---

## The Three Things That Are Supposed to Match

Right after a clean `apply`, three separate things are all saying the same thing:

| Piece | What it actually is | Example in my labs |
|---|---|---|
| Desired configuration | My `.tf` files | `instance_type = "t2.micro"` in `ec2_instances.tf` |
| State | `terraform.tfstate` | Records that instance as `t2.micro`, id `i-036fab...` |
| Real world | The actual EC2 instance in AWS | Actually running as `t2.micro` |

Drift is any situation where one of these three stops matching the other two — usually because the **real world** changed without Terraform knowing about it.

---

## How Drift Actually Happens

The common cause: someone bypasses Terraform and changes the real resource directly.

- A teammate resizes an EC2 instance in the AWS console because it's easier than editing HCL
- An auto-scaling or patching script changes an attribute on its own
- Someone runs an AWS CLI command directly against the resource
- A different tool (CloudFormation, a manual script) manages the same resource

Terraform has no way to know any of this happened — nothing pings it when something changes outside its own `apply`. My `.tf` files still say `t2.micro`, and my state file still says `t2.micro`, even though the real instance in AWS is now `t2.small`. State goes stale the moment reality moves without Terraform being the one to move it.

---

## How `terraform plan` Detects It

Terraform doesn't wait for me to notice. Every `terraform plan` (and `apply`) automatically **refreshes** state first — it queries the actual provider (AWS, in every lab here) for each managed resource's current real attributes, before comparing anything to my `.tf` files. That's confirmed straight from the current Terraform docs: *plan* refreshes state as a normal part of building a plan, so drift shows up automatically, without me having to ask for it.

```bash
terraform plan
```

If AWS reports the instance as `t2.small` but my config still says `t2.micro`, that mismatch shows up right in the plan output as a proposed change — Terraform read the real value, compared it to my config, and is telling me they disagree.

> 📌 **Worth knowing, and something this repo's own [Module 4.3](../module-04.3-state-complete-guide/README.md#-refresh-state) got wrong:** there used to be a standalone `terraform refresh` command for forcing this refresh manually. It's **deprecated** — confirmed against the current Terraform CLI docs, which say to use the `-refresh-only` flag on `plan`/`apply` instead. The reason: `terraform refresh` used to apply the refreshed values to state immediately, with no chance to review them first. `-refresh-only` gives me a plan to look at (and, on `apply`, a confirmation prompt) before anything gets written to state. I've updated 4.3's "Refresh State" section to point here instead of teaching the deprecated command as current.

---

## Fixing Drift, Two Ways

Once `plan` shows me drift, I have to decide which side is actually correct — my config, or the real world — because the fix is different depending on the answer.

### 1. Revert — make reality match my config

Use this when the external change was a mistake, or shouldn't have happened outside Terraform. My config stays the source of truth; I use Terraform to push the real resource back to what the config says.

```bash
terraform plan   # shows the drift as a change to make
terraform apply  # pushes the real resource back to match my config
```

This is just an ordinary `apply` — nothing special about it. Terraform calls the provider's API to change the real resource back, then updates state to match. **Whether that means an in-place update or a full replace depends on the specific attribute that drifted** — I confirmed this the hard way in [Module 5.2](../../module-05-working-with-terraform/module-05.2-mutable-vs-immutable-infrastructure/README.md#️-counterintuitive-one): reverting a drifted `instance_type` (`t2.small` back to `t2.micro`) is a quiet in-place resize, same instance ID throughout — but reverting a drifted `ami` would destroy and recreate the instance, because `ami` actually is `ForceNew`. Same "revert" action, very different blast radius depending on what changed.

### 2. Adopt — make my config (and state) match reality

Use this when the external change was *intentional* and should become the new desired state — someone resized the instance for a real reason, and I want Terraform to accept that going forward instead of fighting it every `apply`.

```bash
# Step 1: preview what a refresh would change, without touching anything
terraform plan -refresh-only

# Step 2: actually write the refreshed values into state (asks for confirmation)
terraform apply -refresh-only
```

**This only updates the state file — it does not touch my `.tf` files.** That's the part that's easy to miss: after `apply -refresh-only`, state says `t2.small` and the real instance is `t2.small`, but my config still says `t2.micro`. Terraform doesn't rewrite my HCL for me. I have to go edit `instance_type = "t2.micro"` to `"t2.small"` by hand:

```bash
# Step 3: manually update the .tf file to match what I just adopted
# Step 4: confirm everything now agrees
terraform plan   # should show "No changes" if I matched it correctly
```

Only once all three — config, state, and the real instance — say `t2.small` is drift actually resolved. Stopping after step 2 leaves the config permanently out of sync with the other two, which is its own kind of drift.

---

## Is This Permanent? Do I Have to Keep Refreshing?

No — adopting a change is a **one-time fix**, not something I repeat forever. Once state and my `.tf` file both say `t2.small`, Terraform treats `t2.small` as the correct, expected value from then on and manages it completely normally. I'd only run `-refresh-only` again if a *different* manual change happened later that I also wanted to keep.

---

## This Isn't What `terraform import` Is For

Easy to mix these up, since both involve "AWS has something Terraform didn't put there" — but they're solving different problems:

| Situation | What Terraform already knows | Fix |
|---|---|---|
| **Drift** (this note) | The resource is already in my state file — Terraform created it. Someone just changed one of its *attributes* outside Terraform. | `apply -refresh-only` + hand-edit my `.tf` file. **No `import` involved.** |
| **Untracked resource** | The resource isn't in my state file **at all**. The whole thing was created by hand, outside Terraform, from scratch. | `terraform import` (or the newer `import` block) to add it to state, **plus** I still have to write the matching `.tf` resource block myself — import only updates state, same as `-refresh-only` does. |

The test: if Terraform already created the resource and someone just tweaked an attribute afterward, that's drift — `import` has nothing to do with it. `import` is only for a resource Terraform has zero history with, like an instance a teammate launched by hand in the console that I now want Terraform to start managing.

---

## Quick Reference

| Command | What it touches | Use it when |
|---|---|---|
| `terraform plan` | Nothing — read-only, but does refresh state in memory first | Checking for drift before deciding anything |
| `terraform apply` | Real resource **and** state | Reverting drift — pushing reality back to match config |
| `terraform apply -refresh-only` | **State only**, not the real resource, not my `.tf` files | Adopting drift into state — first half of accepting an external change |
| `terraform refresh` | State only | ❌ Deprecated — use `-refresh-only` instead |

---

## Preventing Drift

The real fix is making drift rare in the first place, not just getting good at detecting it:

- Restrict who can make direct console/CLI changes with IAM — if only Terraform's role can write to a resource, drift can't happen by accident
- Route all changes through pull requests and a CI/CD pipeline that runs Terraform, instead of anyone applying from their own laptop whenever
- Run `terraform plan` on a schedule (even with nothing changed in the repo) so drift gets caught within hours, not discovered by accident weeks later

> ⚠️ **Don't lean on `-refresh-only` as a standing workaround.** It's for deliberately adopting a one-off external change, not a substitute for actually preventing them. If I find myself running `-refresh-only` constantly, that's a sign something outside Terraform keeps touching this resource, and the real fix is locking that down — not getting good at absorbing the drift.

---

## Summary

Drift is what happens when the real world changes without Terraform being the one to change it — config, state, and reality stop agreeing, and `terraform plan` is what surfaces the mismatch, because it refreshes state from the real provider before comparing anything to my `.tf` files.

We covered:
- ✅ The three things that should always match: config, state, real world
- ✅ How drift happens — anything that changes a resource outside Terraform
- ✅ `terraform plan` always refreshes first, which is how drift gets caught automatically
- ✅ Two fixes: **revert** (`apply`, real world moves back to match config) vs. **adopt** (`apply -refresh-only`, state moves to match real world — then I still have to hand-edit my `.tf` files myself)
- ✅ The standalone `terraform refresh` command is deprecated in favor of `-refresh-only`
- ✅ Reverting drift can be an in-place update or a full replace, depending on whether the drifted attribute is `ForceNew` — see [Module 5.2](../../module-05-working-with-terraform/module-05.2-mutable-vs-immutable-infrastructure/README.md)

---

## Key Takeaway

**Drift = the real world moved without Terraform. `terraform plan` catches it because it always refreshes first.**

- ✅ Revert drift with a normal `apply` — makes reality match my config again
- ✅ Adopt drift with `apply -refresh-only` — makes *state* match reality, but I still have to update my `.tf` files myself afterward
- ⚠️ `-refresh-only` never touches my `.tf` files or the real resource — only state
- ❌ Standalone `terraform refresh` is deprecated — use `-refresh-only` on `plan`/`apply`

---

## Practice & Next Steps

Pick any resource from an existing lab in this repo, change one non-`ForceNew` attribute (like `instance_type`) directly in the AWS console, then run `terraform plan` and watch it get flagged as drift without touching the config first. Try both paths on it: revert with a plain `apply`, then manually re-drift it and adopt the change instead with `-refresh-only` followed by a manual `.tf` edit — confirm `terraform plan` comes back clean only after all three (config, state, reality) agree again.

---

## Related Notes

- [Module 4.5: State Loss and Recovery](../module-04.5-state-loss-and-recovery/README.md) — the sibling failure mode: instead of state and reality quietly disagreeing, state goes missing entirely. Different cause, different fix (recreate or `import`, not `-refresh-only`)
