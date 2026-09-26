region             = "eu-west-1"
environment        = "staging"
vpc_cidr           = "10.1.0.0/16"
public_subnet_cidr = "10.1.1.0/24"
ssh_cidr           = "2.82.252.24/32" # replace with my IP from: curl ifconfig.me
instance_type      = "t3.small"