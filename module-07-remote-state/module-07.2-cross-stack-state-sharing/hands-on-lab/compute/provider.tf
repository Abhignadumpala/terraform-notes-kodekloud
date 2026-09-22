terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Same bucket as network/, different key - two stacks, one shared backend.
  backend "s3" {
    bucket       = "tf-remote-state-lab-9506214d"
    key          = "compute/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = "us-east-1"
}
