terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend blocks can't reference variables or outputs from another config -
  # this bucket name has to be typed in by hand, copied from bootstrap's
  # `state_bucket_name` output.
  backend "s3" {
    bucket       = "tf-state-mutable-immutable-lab-5c2c73f8" # from bootstrap's state_bucket_name output
    key          = "state-locking-lab/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true # native S3 locking - no DynamoDB table needed
    encrypt      = true
  }
}

provider "aws" {
  region = "us-east-1"
}
