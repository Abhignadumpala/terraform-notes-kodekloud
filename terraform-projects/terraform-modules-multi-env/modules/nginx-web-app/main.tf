# Network — VPC, public subnet, internet gateway, route table

module "vpc" {
  source = "../vpc"

  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
}

# Firewall — needs the VPC id from the vpc module

module "security_group" {
  source = "../security-group"

  environment = var.environment
  vpc_id      = module.vpc.vpc_id
  ssh_cidr    = var.ssh_cidr
}

# IAM role for EC2 — doesn't need anything from the other modules

module "iam" {
  source = "../iam"

  environment = var.environment
}

# Web server — needs subnet, SG and instance profile from the three modules above

module "ec2" {
  source = "../ec2"

  environment           = var.environment
  instance_type         = var.instance_type
  subnet_id             = module.vpc.public_subnet_id
  security_group_id     = module.security_group.security_group_id
  instance_profile_name = module.iam.instance_profile_name
  key_name              = var.key_name
}