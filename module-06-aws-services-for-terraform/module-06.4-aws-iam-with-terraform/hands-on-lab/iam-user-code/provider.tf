terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# No access_key/secret_key here on purpose - credentials come from
# `aws configure` (~/.aws/credentials) or AWS_* environment variables.
provider "aws" {
  region = "us-east-1" # change to whichever region I have free-tier access in
}
