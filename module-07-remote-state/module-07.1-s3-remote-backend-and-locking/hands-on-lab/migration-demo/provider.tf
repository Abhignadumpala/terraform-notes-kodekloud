terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # current: 5.x/6.x - the original lesson ran this against v3.7.0
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
