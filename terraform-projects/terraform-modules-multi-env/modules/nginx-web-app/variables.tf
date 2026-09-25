# Environment name — passed down to every module

variable "environment" {
  description = "Environment name, e.g. dev"
  type        = string
}

# Network ranges — for the vpc module

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
}

# My IP for SSH — for the security-group module

variable "ssh_cidr" {
  description = "CIDR allowed to SSH"
  type        = string
}

# Server settings — for the ec2 module

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "key_name" {
  description = "Existing EC2 key pair name, or null"
  type        = string
  default     = null
}