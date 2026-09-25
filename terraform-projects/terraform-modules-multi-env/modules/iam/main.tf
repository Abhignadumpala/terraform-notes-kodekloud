# IAM role — an identity that EC2 is allowed to "wear"

resource "aws_iam_role" "nginx_ec2_role" {
  name = "${var.environment}-nginx-ec2-role"

  # Trust policy — only the EC2 service can use this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.environment}-nginx-ec2-role"
  }
}

# Attach AWS's ready-made SSM policy — lets me connect with Session Manager

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.nginx_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile — the "holder" that attaches the role to an EC2 instance

resource "aws_iam_instance_profile" "nginx_profile" {
  name = "${var.environment}-nginx-ec2-profile"
  role = aws_iam_role.nginx_ec2_role.name
}