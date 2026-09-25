# Environment name — used in the SG name and tags

variable "environment" {
  description = "Environment name, e.g. dev"
  type        = string
}

# Which VPC this SG belongs to — comes from the vpc module output

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

# My IP for SSH — find it with: curl ifconfig.me   then add /32

variable "ssh_cidr" {
  description = "CIDR allowed to SSH, e.g. 203.0.113.10/32"
  type        = string
}