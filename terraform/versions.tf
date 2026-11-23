terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # any 6.x, never 7.x (major versions can break things)
    }
  }
}

provider "aws" {
  region = var.region

  # Stamped on every resource, so in the console you can tell what Terraform owns
  default_tags {
    tags = {
      Project   = "homelab"
      ManagedBy = "terraform"
    }
  }
}