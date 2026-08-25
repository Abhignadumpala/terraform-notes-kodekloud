resource "aws_instance" "web_server" {
  ami           = "ami-054d6a336762e438e"  # Ubuntu 20.04 LTS (us-east-1)
  instance_type = "t2.micro"
  
  # THIS IS THE LINKING! References security group ID dynamically
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  
  tags = {
    Name = "web-server"
  }
}
