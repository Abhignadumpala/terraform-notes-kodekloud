# In a real account, this group and its members would already exist,
# created by someone else - I'm creating them here only so this lab is
# self-contained and can be applied on its own, per the hands-on-lab
# convention in this repo.

resource "aws_iam_user" "finance_analyst_1" {
  name = "meena"
  tags = {
    Description = "Finance Analyst"
  }
}

resource "aws_iam_group" "finance_analysts" {
  name = "finance-analysts"
}

resource "aws_iam_group_membership" "finance_analysts" {
  name  = "finance-analysts-membership"
  group = aws_iam_group.finance_analysts.name
  users = [aws_iam_user.finance_analyst_1.name]
}
