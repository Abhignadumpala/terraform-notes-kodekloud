data "aws_iam_group" "finance_analysts" {
  group_name = aws_iam_group.finance_analysts.name

  # Without this, Terraform could read the group before the membership
  # resource above actually adds meena to it, and the policy below would
  # end up with an empty Principal list.
  depends_on = [aws_iam_group_membership.finance_analysts]
}

# IAM groups can't be used as a Principal in a bucket policy - listing
# the group's individual member ARNs instead is the correct approach.
resource "aws_s3_bucket_policy" "finance_policy" {
  bucket = aws_s3_bucket.finance.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "*",
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.finance.id}/*",
      "Principal": {
        "AWS": ${jsonencode(data.aws_iam_group.finance_analysts.users[*].arn)}
      }
    }
  ]
}
EOF
}
