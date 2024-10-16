terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    region = "us-east-1"  # change your region
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-south-1"
#   assume_role {
#     role_arn     = "arn:aws:iam::123456789012:role/ROLE_NAME"
#     session_name = "SESSION_NAME"
#     external_id  = "EXTERNAL_ID"
#   }
}
