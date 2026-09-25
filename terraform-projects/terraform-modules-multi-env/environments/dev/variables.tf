# AWS region to deploy into

variable "region" {
  description = "AWS region, e.g. eu-west-1"
  type        = string
}

# Environment name — dev, staging or production

variable "environment" {
  description = "Environment name"
  type        = string
}

# IP range for the whole VPC

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

# IP range for the public subnet — must fit inside vpc_cidr

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
}

# My IP for SSH — x.x.x.x/32

variable "ssh_cidr" {
  description = "CIDR allowed to SSH"
  type        = string
}

# Server size

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

# SSH key pair name — optional, null means use Session Manager only

variable "key_name" {
  description = "Existing EC2 key pair name, or null"
  type        = string
  default     = null
}