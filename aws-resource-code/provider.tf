# Cloud provider info: which provider Terraform downloads, and which AWS region it creates things in.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # change to whichever region I have free-tier access in
}
