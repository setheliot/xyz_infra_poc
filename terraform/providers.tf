# AWS Provider configuration
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.70.0"
    }
  }
}
provider "aws" {
  region = var.aws_region
}

# Remote backend for storing Terraform state
terraform {
  backend "s3" {
    bucket         = "seliot-terraform-state-bucket"
    key            = "xyz_infra_poc/terraform.tfstate"
    dynamodb_table = "terraform-lock"
    region         = "us-east-1"
    encrypt        = true
  }
}

