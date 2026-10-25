# Subnets: smaller pieces of the VPC, each in one Availability Zone.
# Public subnet = for servers the internet can reach (it gets a route to the internet gateway in route_table.tf).
# Private subnet = no route to the internet; for databases and internal servers.

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true # instances launched here get a public IP automatically

  tags = {
    Name = "Mr_cloud_public_subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Mr_cloud_private_subnet"
  }
}
