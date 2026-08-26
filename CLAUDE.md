# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal study notes for the KodeKloud Terraform course. There is no application code, no build, no lint, and no test suite — content is Markdown notes plus small illustrative `.tf` snippets used for hands-on labs. Do not introduce build/lint/test tooling unless the user asks for it.

## Commands

- No build/lint/test commands exist for this repo.
- `.tf` files under `hands-on-lab/` folders are lab snippets tied to a specific lesson, not a deployable stack — don't assume they compose with each other across modules. If asked to run one, standard Terraform commands apply (`terraform init`, `terraform plan`, `terraform apply`, `terraform destroy`) from inside that specific lab folder.
- Git commit messages in this repo follow a `<Verb>: <description>` convention (e.g. `Add: Module 03.8 - Resource Dependencies in Terraform with AWS`, `Fix: Update image references...`). Match this style when committing.

## Structure and conventions

Content is organized by course module, each split into numbered sub-lessons:

```
module-0<N>-<topic>/
  module-0<N>.<M>-<sub-topic>/
    <sub-topic>.md          # or README.md — see inconsistency note below
    images/                 # numbered screenshots referenced by the .md
    hands-on-lab/           # actual .tf files from the lab, if the lesson had one
```

- `core-workflow/` and `terraform-cli-vs-cloud.md` at the repo root are standalone notes not tied to a single module number.
- When adding a new sub-lesson (e.g. `03.9`), follow the existing sibling folders in that module for naming — check 1-2 neighboring folders first, since conventions have drifted (see below), and match the most recent one rather than the oldest.

**Known inconsistencies — don't "fix" these unless asked, just be aware when navigating or adding new content:**
- Primary note file naming varies: most modules use `<topic-name>.md`, but `module-03.8-resource-dependencies-in-terraform/` uses `README.md` instead.
- `module-02.2-hashicorp-configuration-language-hcl-basics/` contains the `.md` files for sub-lessons 02.1, 02.2, *and* 02.3 all in one folder (not split into separate `module-02.1-...`, `module-02.3-...` folders like module-03 is).
- One file has a space instead of a hyphen after the module number: `module 02.1-installing-terraform.md`.
- Some hands-on labs nest an extra topic subfolder instead of a flat `hands-on-lab/` (e.g. `module-03.6-.../using-variables-with-aws-infrastructure/README.md`).

## Notes content style

Notes are written in first person from the learner's perspective (e.g. "When I run `terraform init`..."), with headered sections, occasional emoji section markers, and cross-links back to related lessons ("Back to why terraform" style links). Match this voice when writing new notes rather than switching to a generic/third-person tone.
