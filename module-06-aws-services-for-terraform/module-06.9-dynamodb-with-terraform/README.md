# 📘 Module 6.9: DynamoDB with Terraform

> [6.7](../module-06.7-introduction-to-dynamodb/README.md) and [6.8](../module-06.8-demo-dynamodb/README.md) covered DynamoDB as theory and console clicks. This is where I create the same shape of table with Terraform instead.

---

## Introduction

A table and its items, as actual resource blocks: `aws_dynamodb_table` for the table, `aws_dynamodb_table_item` for the rows inside it — the same pattern [6.4](../module-06.4-aws-iam-with-terraform/README.md) used for IAM and [6.6](../module-06.6-s3-with-terraform/README.md) used for S3.

> 🧪 **Hands-on lab:** [DynamoDB with Terraform](hands-on-lab/README.md) — deploy a table and two items for real, with the actual `plan`/`apply` output and console screenshots.

---

## Creating a DynamoDB Table Resource

`aws_dynamodb_table` is the resource — [the source of truth for its arguments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table). Unlike the console wizard from [6.8](../module-06.8-demo-dynamodb/README.md#creating-a-table), Terraform needs the partition key spelled out twice: once as `hash_key`, and again as its own `attribute` block declaring the type:

```hcl
resource "aws_dynamodb_table" "employee_data" {
  name         = "employee_data"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "employee_id"

  attribute {
    name = "employee_id"
    type = "N"
  }

  tags = {
    Description = "Employee data"
  }
}
```

> 💡 `attribute` blocks are only for attributes that are part of a key (`hash_key`, `range_key`, or a secondary index's key) — same idea as [6.8](../module-06.8-demo-dynamodb/README.md#adding-items)'s console point that only the primary key is mandatory on an item. `name`/`age`/`role` don't get `attribute` blocks here; DynamoDB still doesn't care what non-key attributes an item has until an item actually shows up with one.

`billing_mode = "PAY_PER_REQUEST"` is Terraform's name for what the console calls **On-Demand** capacity mode — the console's own current default, per [6.8](../module-06.8-demo-dynamodb/README.md#creating-a-table). The other option is `"PROVISIONED"`, which additionally requires `read_capacity`/`write_capacity` arguments (the RCU/WCU numbers the console used to ask for by default).

`terraform apply` creates the table the same way `terraform apply` created a bucket in [6.6](../module-06.6-s3-with-terraform/README.md#creating-an-s3-bucket) — one resource, one `Plan: 1 to add`.

---

## Adding Items with `aws_dynamodb_table_item`

An item is its own resource, `aws_dynamodb_table_item` — [source of truth here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table_item). It needs the table name, the hash key's name, and the item itself as a JSON string in DynamoDB's own attribute-typed format (`{"S": ...}` for a string, `{"N": ...}` for a number):

```hcl
resource "aws_dynamodb_table_item" "example" {
  table_name = aws_dynamodb_table.employee_data.name
  hash_key   = aws_dynamodb_table.employee_data.hash_key

  item = <<ITEM
{
  "employee_id": {"N": "1"},
  "name": {"S": "example"},
  "age": {"N": "30"},
  "role": {"S": "example role"}
}
ITEM
}
```

> ⚠️ That `item` JSON isn't plain JSON — every value is wrapped in its DynamoDB attribute-type key (`S`, `N`, `BOOL`, …), because this is the same low-level item format the DynamoDB API itself uses, not a Terraform convenience shape. Forgetting the wrapper (`"name": "example"` instead of `"name": {"S": "example"}`) is a `ValidationException` at apply time, not something `terraform validate` catches beforehand.

One `aws_dynamodb_table_item` resource per item — same "each row is its own thing" idea as items in the console, just declared instead of clicked through **Create Item**.

---

## Summary

- ✅ `aws_dynamodb_table` needs `name`, `billing_mode`, `hash_key`, and an `attribute` block per key attribute — non-key attributes get no `attribute` block at all
- ✅ `billing_mode = "PAY_PER_REQUEST"` is On-Demand; `"PROVISIONED"` is the other option, and additionally needs `read_capacity`/`write_capacity`
- ✅ `aws_dynamodb_table_item` is a separate resource per item, referencing the table by name and its hash key
- ⚠️ An item's JSON uses DynamoDB's typed attribute format (`{"S": ...}`/`{"N": ...}`), not plain JSON — a missing type wrapper only fails at `apply`, not `validate`

---

## Key Takeaway

**A table and its items are two different resource types — same split as `aws_s3_bucket` vs. `aws_s3_object` in [6.6](../module-06.6-s3-with-terraform/README.md), just for DynamoDB.**

- ✅ Only key attributes get declared up front, in an `attribute` block — everything else an item might carry stays undeclared until an item actually has it
- ⚠️ `aws_dynamodb_table_item`'s JSON is DynamoDB's own wire format, not a Terraform shorthand — the `{"S": ...}`/`{"N": ...}` wrapper is mandatory

---

## Practice & Next Steps

Run the [hands-on lab](hands-on-lab/README.md): deploy the table and its two items, confirm them in the console's **Explore items** view, then change one item's `age` and re-apply — confirm the plan updates that one item in place rather than replacing the table.

That wraps up Module 6 — IAM, S3, and DynamoDB, each covered as theory, a console demo, and a Terraform resource.
