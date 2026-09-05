terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend blocks can't reference variables or outputs from another config -
  # these values have to be typed in by hand, copied from the bootstrap
  # outputs (`state_bucket_name`, `lock_table_name`).
  backend "s3" {
    bucket         = "tf-state-mutable-immutable-lab-47393c8b" # from bootstrap's state_bucket_name output
    key            = "state-locking-lab/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locks" # from bootstrap's lock_table_name output
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}
