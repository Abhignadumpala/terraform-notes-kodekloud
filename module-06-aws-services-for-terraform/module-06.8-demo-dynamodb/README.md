# 📘 Module 6.8: Demo DynamoDB — Creating a Table in the Console

> [6.7](../module-06.7-introduction-to-dynamodb/README.md) covered items, attributes, and primary keys as theory. This lesson is the same ideas clicked through by hand: create a table, add a couple of employees, filter down to just the one I care about.

---

## Introduction

This is the hands-on follow-up to [6.7](../module-06.7-introduction-to-dynamodb/README.md): create a table to store employee data, add a couple of items with different attributes, and filter the results down by one of those attributes. I ran this one for real in my own account — see the [hands-on lab](hands-on-lab/README.md) for the actual screenshots. Nothing here touches Terraform yet — that's next.

---

## Accessing DynamoDB

1. **Services** (top left) → under **Databases**, select **DynamoDB**.
2. Click **Create Table**.

---

## Creating a Table

I name the table `employee_data`, and set the primary key (partition key) to `employee_id`, type **Number** — the same "one attribute that must be unique per item" idea from [6.7](../module-06.7-introduction-to-dynamodb/README.md#primary-keys). No sort key needed for this shape of data.

> ⚠️ **What's changed since this course was recorded:** back then, "leave the other settings at their default" meant **Provisioned** capacity mode — I'd have had to type in read/write capacity units, and DynamoDB's Always Free tier (25 GB storage + 25 RCU + 25 WCU) would have covered a table this small at no cost. Today, the console's **Default settings** option lands on **On-Demand** capacity mode instead (confirmed against my own table — see the [hands-on lab](hands-on-lab/README.md#1-create-the-table)) — AWS now recommends it for most workloads, and it needs no capacity planning at all. The tradeoff: [DynamoDB's Always Free tier only applies to Provisioned mode](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/on-demand-capacity-mode.html) — an On-Demand table is billed per request from the very first read or write, even for a table this size. For a demo table with a couple of items the cost is a fraction of a cent, but it's worth knowing "leave it at default" no longer means "definitely free" the way it used to.

After a few seconds the table's created and shows up in the left sidebar. The **Items** tab is where I go to see its contents — empty, at first.

---

## Adding Items

**Create Item** already has `employee_id` pre-filled, since it's the primary key. I set it to `1`, add `name = lucy`, then go back in afterward and append `age` (Number) and `role` (String):

```json
{
  "employee_id": 1,
  "name": "lucy",
  "age": 42,
  "role": "team lead"
}
```

A second item, `employee_id = 2`:

```json
{
  "employee_id": 2,
  "name": "lee",
  "age": 29,
  "role": "developer"
}
```

> 💡 Only the primary key is required on an item — every other attribute is optional, and different items don't need the same set of attributes. Both of my items here happen to have every attribute filled in, so it doesn't show up in this particular pair — see the [hands-on lab's note on that](hands-on-lab/README.md#3-add-the-second-item-lee) — but nothing stops an item from skipping `role` (or `age`, or both) entirely, same as [6.7](../module-06.7-introduction-to-dynamodb/README.md#primary-keys)'s flexible-schema point.

---

## Filtering Items

To find specific items without scanning the whole table by eye, I apply a filter on an attribute — here, filtering `role` down to just `developer`, so the table view collapses to just Lee's row.

> ⚠️ Worth being precise about what this console filter actually does: it's a **filter expression**, applied *after* DynamoDB has already read the matching items — not a query that only reads `role = developer` items off disk. My own run against this two-item table made that concrete: **Items scanned: 2, Items returned: 1, Efficiency: 50%** (see the [hands-on lab](hands-on-lab/README.md#4-filter-down-to-just-the-developers)) — DynamoDB read both items and only then dropped the one that didn't match. Invisible on a table this small, but on a large table, filtering post-read is why filtering on anything other than the primary key doesn't save on read cost the way an actual key-based query does. See the [official filter-expression docs](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Query.FilterExpression.html) if this comes up again once queries via Terraform-provisioned tables are in the picture.

---

## Summary

- ✅ DynamoDB lives under Services → Databases
- ✅ Created `employee_data` with `employee_id` (Number) as the partition key
- ✅ Added two items with **Create Item** + **Append** for extra attributes — only the primary key is mandatory (neither of mine actually left an attribute off, but nothing requires them to match)
- ✅ Filtered the table down to the one item matching an attribute value (`role = developer`) — confirmed as a scan-then-drop, not a targeted read, from the "Items scanned" vs. "Items returned" counts
- ⚠️ Console default capacity mode is now On-Demand, not Provisioned — the Always Free tier (25 RCU/WCU) only covers Provisioned mode, so a default-settings table today is billed per-request from the start (negligible cost for a demo, but not literally free the way it used to be)

---

## Key Takeaway

**Every concept from 6.7 plays out the same way in the console: a table needs just a primary key to exist, an item needs just that key's value to be valid, and everything else is optional and addable ad hoc.**

- ✅ `employee_id` alone was enough to create the table — no schema for `name`/`age`/`role` had to be declared up front
- ✅ Items in the same table *can* have different attributes — mine happened not to, but nothing enforces uniformity
- ⚠️ "Default settings" today means On-Demand billing, not the Provisioned + Always-Free-tier default this course was recorded against
- ⚠️ A console filter costs the same read as scanning the whole table — it just hides the non-matching rows afterward

---

## Practice & Next Steps

Run the [hands-on lab](hands-on-lab/README.md): create this same `employee_data` table, add a couple of items, and this time deliberately leave an attribute off one of them to actually see the flexible-schema point instead of just reading about it. Then filter on more than one attribute at once, and check the table's **Capacity mode** setting.

Next up in Module 6: wiring DynamoDB into Terraform — `aws_dynamodb_table` and the resources that go with it, the same way [6.4](../module-06.4-aws-iam-with-terraform/README.md) did for IAM and [6.6](../module-06.6-s3-with-terraform/README.md) did for S3.
