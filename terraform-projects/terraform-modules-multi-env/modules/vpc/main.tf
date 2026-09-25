# Look up which Availability Zones are available in my region

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC — my own private network in AWS, everything else lives inside it

resource "aws_vpc" "nginx_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true # EC2 gets a public DNS name
  enable_dns_support   = true # DNS lookups work inside the VPC

  tags = {
    Name = "${var.environment}-vpc"
  }
}

# Public subnet — a smaller network inside the VPC where my EC2 will run

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.nginx_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0] # first AZ in the list
  map_public_ip_on_launch = true                                           # EC2 gets a public IP so I can reach nginx

  tags = {
    Name = "${var.environment}-public-subnet"
  }
}

# Internet gateway — the door between my VPC and the internet

resource "aws_internet_gateway" "nginx_igw" {
  vpc_id = aws_vpc.nginx_vpc.id

  tags = {
    Name = "${var.environment}-igw"
  }
}

# Route table — sends all internet traffic (0.0.0.0/0) through the gateway

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.nginx_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nginx_igw.id
  }

  tags = {
    Name = "${var.environment}-public-rt"
  }
}

# Route table association — attaches the route table to my subnet,this is what makes the subnet "public"

resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}