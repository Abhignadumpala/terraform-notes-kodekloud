# VPC creation: my own private network in AWS.
# 10.0.0.0/16 gives 65,536 IP addresses that my subnets are cut from.

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true # EC2 instances get DNS names like ec2-1-2-3-4.compute-1.amazonaws.com

  tags = {
    Name = "Mr_cloud_vpc"
  }
}
