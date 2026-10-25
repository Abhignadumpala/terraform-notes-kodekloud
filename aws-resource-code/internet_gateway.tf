# Internet gateway: the door between my VPC and the internet.
# Attaching it to the VPC is not enough on its own - a route table must also point to it (route_table.tf).

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Mr_cloud_igw"
  }
}
