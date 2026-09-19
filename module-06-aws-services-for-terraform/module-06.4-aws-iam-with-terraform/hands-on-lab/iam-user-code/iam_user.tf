resource "aws_iam_user" "admin-user" {
  name = "priya"
  tags = {
    Description = "DevOps Engineer"
  }
}

resource "aws_iam_user" "readonly-user" {
  name = "raj"
  tags = {
    Description = "Reporting Analyst - S3 read-only"
  }
}
