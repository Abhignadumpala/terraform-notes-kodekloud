variable "environment" {
  description = "Environment name (dev or prod) - drives the conditional instance sizing"
  type        = string
}

variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
}
