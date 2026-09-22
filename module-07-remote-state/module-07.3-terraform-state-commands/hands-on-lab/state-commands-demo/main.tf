# Two resources: one to rename with `state mv` (the DynamoDB table, matching
# the course lesson's own example), one to detach with `state rm` (the S3
# bucket) without destroying the real thing in AWS.

resource "aws_dynamodb_table" "app_configuration" {
  name         = "app-config"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

resource "aws_s3_bucket" "reports" {
  bucket = "tf-state-cmds-reports-8f2a1"

  tags = {
    Description = "State commands demo - detached with state rm not destroyed"
  }
}
