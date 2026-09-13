terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.60.0"  # Proven stable version
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

