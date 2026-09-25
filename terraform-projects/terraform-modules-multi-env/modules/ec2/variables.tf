# Environment name — used in the Name tag and the web page

variable "environment" {
  description = "Environment name, e.g. dev"
  type        = string
}

# Instance size — small for dev, bigger for production

variable "instance_type" {
  description = "EC2 instance type, e.g. t3.micro"
  type        = string
}

# Where to launch — comes from the vpc module

variable "subnet_id" {
  description = "ID of the public subnet"
  type        = string
}

# Firewall — comes from the security-group module

variable "security_group_id" {
  description = "ID of the nginx security group"
  type        = string
}

# IAM — comes from the iam module

variable "instance_profile_name" {
  description = "Name of the IAM instance profile"
  type        = string
}

# SSH key pair name — optional, leave null to use Session Manager only

variable "key_name" {
  description = "Existing EC2 key pair name for SSH"
  type        = string
  default     = null
}