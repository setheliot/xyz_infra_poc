# TODO: move Region, bucket name, and DDB table name to variables.tf

# AWS Provider configuration
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

