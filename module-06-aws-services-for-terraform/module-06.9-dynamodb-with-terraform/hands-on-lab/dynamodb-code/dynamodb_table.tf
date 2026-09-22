# Named employee_data_tf, not employee_data - that name's already taken in
# this account by the table I created by hand in 6.8's console demo.
# DynamoDB table names only need to be unique per account+region (unlike
# S3 bucket names), but reusing the exact same name here would either
# collide on apply or require importing the console table first.

resource "aws_dynamodb_table" "employee_data" {
  name         = "employee_data_tf"
  billing_mode = "PAY_PER_REQUEST" # On-Demand - matches the console's own default from 6.8
  hash_key     = "employee_id"

  attribute {
    name = "employee_id"
    type = "N"
  }

  tags = {
    Description = "Employee data - created via Terraform"
  }
}
