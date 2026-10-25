# IAM user: a login identity for a person.

resource "aws_iam_user" "dev" {
  name = "mr-cloud-dev"
}

# IAM group: I give permissions to the group, then add users to it,
# instead of giving permissions to each user one by one.

resource "aws_iam_group" "developers" {
  name = "mr-cloud-developers"
}

resource "aws_iam_user_group_membership" "dev" {
  user   = aws_iam_user.dev.name
  groups = [aws_iam_group.developers.name]
}

# Attach an AWS managed policy (read-only access to everything) to the group.

resource "aws_iam_group_policy_attachment" "read_only" {
  group      = aws_iam_group.developers.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
