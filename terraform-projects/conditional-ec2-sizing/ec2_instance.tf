resource "aws_instance" "app" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.environment == "prod" ? "t2.medium" : "t2.micro"

  tags = {
    Name        = var.instance_name
    Environment = var.environment
  }
}
