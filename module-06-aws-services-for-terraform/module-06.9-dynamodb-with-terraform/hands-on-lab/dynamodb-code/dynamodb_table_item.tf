# Different employee names from 6.8's console demo (lucy/lee) - keeps the
# Terraform-managed items clearly distinct from what I already created by
# hand in the console, even though they'd live in separate tables anyway.

resource "aws_dynamodb_table_item" "abdul" {
  table_name = aws_dynamodb_table.employee_data.name
  hash_key   = aws_dynamodb_table.employee_data.hash_key

  item = <<ITEM
{
  "employee_id": {"N": "1"},
  "name": {"S": "abdul"},
  "age": {"N": "33"},
  "role": {"S": "manager"}
}
ITEM
}

resource "aws_dynamodb_table_item" "sara" {
  table_name = aws_dynamodb_table.employee_data.name
  hash_key   = aws_dynamodb_table.employee_data.hash_key

  item = <<ITEM
{
  "employee_id": {"N": "2"},
  "name": {"S": "sara"},
  "age": {"N": "27"},
  "role": {"S": "analyst"}
}
ITEM
}
