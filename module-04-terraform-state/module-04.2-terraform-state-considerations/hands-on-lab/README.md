# Hands-On Lab: S3 Backend + DynamoDB State Locking

> Companion hands-on lab for [Module 04.2: Terraform State Considerations](../README.md#securing-state-in-s3). Code lives in [`bootstrap/`](bootstrap) and [`app/`](app).

---

## What This Lab Tests

[Module 04.2](../README.md) lists remote state + locking as best practice but doesn't show either one happening. This lab does:

1. **Remote state** — move state off my laptop and into an S3 bucket instead of a local `terraform.tfstate`.
2. **State locking** — see what Terraform actually does when a lock is already held, using DynamoDB as the lock table.

Two separate configs, on purpose:

- **`bootstrap/`** — creates the S3 bucket and DynamoDB table. Stays on **local** state, because it's creating the very backend that other configs will point at — it can't use a backend that doesn't exist yet.
- **`app/`** — a single free-tier EC2 instance (the instance itself is incidental — this lab is about where its state lives, not the instance), configured to use the S3 bucket + DynamoDB table from `bootstrap/` as its `backend "s3"`.

---

## Walking Through It

### 1. Create the backend resources

```bash
cd bootstrap
terraform init
terraform apply
```

Creates the S3 bucket (versioned, encrypted, public access blocked) and a `terraform-state-locks` DynamoDB table with `LockID` as its hash key — that specific attribute name and type is what Terraform's S3 backend expects for locking.

Note the outputs:

```
state_bucket_name = "tf-state-mutable-immutable-lab-xxxxxxxx"
lock_table_name   = "terraform-state-locks"
```

### 2. Point `app/` at that bucket

In `app/provider.tf`, replace `tf-state-mutable-immutable-lab-REPLACE-ME` with the real `state_bucket_name` from step 1. (Backend blocks can't reference variables or another config's outputs — this has to be a literal value, typed in by hand or passed via `-backend-config`.)

### 3. Initialize `app/` against the S3 backend

```bash
cd ../app
terraform init
```

Terraform notices there's no backend configured locally yet and asks:

```
Initializing the backend...
Do you want to copy existing state to the new backend?
  Enter a value: yes
```

Say yes. From this point, `app/terraform.tfstate` doesn't exist locally at all — state lives in S3.

### 4. Apply and confirm state actually moved

```bash
terraform apply
```

Creates the EC2 instance:

```
instance_id        = "i-0abc123def456abc"
instance_public_ip = "54.71.34.19"
```

Then check the bucket directly:

```bash
aws s3 ls s3://<state_bucket_name>/state-locking-lab/
```

Should list `terraform.tfstate` — sitting in S3, not in the local folder.

### 5. Simulate a held lock

The realistic way this happens is two people (or two CI jobs) running `apply` at the same moment. The deterministic way to force it for a lab is to write a fake lock item into the DynamoDB table directly, using the same `LockID` Terraform would use — `<bucket>/<key>`:

```bash
aws dynamodb put-item \
  --table-name terraform-state-locks \
  --item '{
    "LockID": {"S": "<state_bucket_name>/state-locking-lab/terraform.tfstate"},
    "Info": {"S": "{\"ID\":\"fake-lock-id\",\"Operation\":\"OperationTypeApply\",\"Who\":\"someone-else@another-machine\"}"}
  }'
```

Now try:

```bash
terraform plan
```

Expect Terraform to refuse outright:

```
Error: Error acquiring the state lock

Lock Info:
  ID:        fake-lock-id
  Path:      <state_bucket_name>/state-locking-lab/terraform.tfstate
  Operation: OperationTypeApply
  Who:       someone-else@another-machine
  Created:   ...

Terraform acquires a state lock to protect the state from being written
by multiple users at the same time. Please resolve the issue above and
try again.
```

This is the entire point of locking: it's what stops two applies from racing each other and corrupting or overwriting each other's state.

### 6. Resolve the lock

Two ways, both legitimate depending on the situation:

```bash
# Option A: you know it's genuinely stale/fake and safe to clear
terraform force-unlock fake-lock-id

# Option B: go straight at the DynamoDB item (what force-unlock does under the hood)
aws dynamodb delete-item \
  --table-name terraform-state-locks \
  --key '{"LockID": {"S": "<state_bucket_name>/state-locking-lab/terraform.tfstate"}}'
```

`terraform plan` should go back to normal immediately after.

### 7. Clean up

```bash
# Remove the EC2 instance first
cd app
terraform destroy

# Then tear down the bucket + lock table
cd ../bootstrap
terraform destroy
```

Order matters here — `bootstrap`'s bucket has `force_destroy = true` specifically so this works even with a state object still inside it, but destroying `app/`'s resource first is still the cleaner sequence (its state literally lives in that bucket).

---

## What This Confirms

| | Local state (default) | S3 + DynamoDB (this lab) |
|---|---|---|
| Where state lives | `terraform.tfstate` on disk | S3 object |
| Visible to teammates/CI | No — one laptop only | Yes — shared |
| Concurrent `apply` protection | None | DynamoDB lock, blocks the second run |
| Lost-laptop risk | State gone with it | State untouched, just re-point at the same backend |
| Encryption at rest | Whatever the disk has | SSE on the bucket, `encrypt = true` in the backend block |

Matches [Module 04.2](../README.md#securing-state-in-s3)'s "Securing State in S3" checklist point for point — this lab is what each of those bullets actually looks like happening.
