data "aws_caller_identity" "current" {}

# S3 bucket names are unique across every AWS account by default, so a
# plain "finance-21092020" (the module note's literal example name) would
# almost certainly already be taken. Appending my account ID guarantees
# uniqueness without needing a random suffix.
resource "aws_s3_bucket" "finance" {
  bucket = "finance-${data.aws_caller_identity.current.account_id}"

  tags = {
    Description = "Finance and Payroll"
  }
}
