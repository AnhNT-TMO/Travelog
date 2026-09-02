terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  # State ở local là đủ cho một người dùng. Nhiều người chạy chung thì đổi sang
  # backend "s3" có DynamoDB lock trước khi apply lần thứ hai.
  # backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "travelog"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
