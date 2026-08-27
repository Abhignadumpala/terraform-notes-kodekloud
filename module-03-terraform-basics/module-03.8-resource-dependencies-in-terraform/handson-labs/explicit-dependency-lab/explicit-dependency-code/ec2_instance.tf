data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "app_server" {
  ami                  = data.aws_ami.amazon_linux.id
  instance_type        = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  depends_on = [
    aws_iam_role_policy.ec2_s3_read  # <- EXPLICIT DEPENDENCY: policy must be attached before the instance boots and assumes the role
  ]

  tags = {
    Name = "app-server-explicit-lab"
  }
}
