resource "aws_iam_user" "admin-user" {
  name = "priya"
  tags = {
    Description = "DevOps Engineer"
  }
}
