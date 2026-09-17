########################################
# EDOS - Event-Driven Order Processing System
# main.tf — Provider + backend configuration
########################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  # ------------------------------------------------------------------
  # Remote state backend (S3 + DynamoDB lock table)
  #
  # Uncomment and fill in once the backend bucket/table exist.
  # These CANNOT be created by this same Terraform config (chicken-and-egg
  # problem — the state needs somewhere to live before it can manage
  # its own backend). Create them manually or via a separate one-off
  # bootstrap script/CLI command, then uncomment this block and run
  # `terraform init -migrate-state`.
  #
  # backend "s3" {
  #   bucket         = "edos-terraform-state-<your-unique-suffix>"
  #   key            = "edos/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "edos-terraform-locks"
  #   encrypt        = true
  # }
  # ------------------------------------------------------------------
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
