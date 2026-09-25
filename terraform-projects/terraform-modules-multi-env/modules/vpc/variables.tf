# Environment name — used in the Name tags (dev, staging, production)

variable "environment" {
  description = "Environment name, e.g. dev"
  type        = string
}

# IP range for the whole VPC

variable "vpc_cidr" {
  description = "CIDR block for the VPC, e.g. 10.0.0.0/16"
  type        = string
}

# IP range for the public subnet — must fit inside vpc_cidr

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet, e.g. 10.0.1.0/24"
  type        = string
}