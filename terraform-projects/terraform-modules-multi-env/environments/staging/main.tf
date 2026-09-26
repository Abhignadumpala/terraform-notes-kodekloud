# Terraform settings — version, provider and where to keep state

terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # State goes to the bootstrap bucket — only the key changes per environment
  backend "s3" {
    bucket       = "abhigna-tfstate-2026"
    key          = "staging/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
  }
}

# AWS provider — default_tags are added to every resource

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "nginx-web-app"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# The whole app — one call, the values come from terraform.tfvars

module "nginx_web_app" {
  source = "../../modules/nginx-web-app"

  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  ssh_cidr           = var.ssh_cidr
  instance_type      = var.instance_type
  key_name           = var.key_name
}