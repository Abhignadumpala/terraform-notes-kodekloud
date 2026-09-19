resource "aws_iam_user_policy_attachment" "priya-admin-access" {
  user       = aws_iam_user.admin-user.name
  policy_arn = aws_iam_policy.adminUser.arn
}

resource "aws_iam_user_policy_attachment" "raj-s3-readonly" {
  user       = aws_iam_user.readonly-user.name
  policy_arn = aws_iam_policy.s3ReadOnly.arn
}
