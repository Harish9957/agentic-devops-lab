terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend config (bucket/key/table/endpoints) is supplied via -backend-config=backend.hcl —
  # backend blocks can't reference variables, so the use_floci toggle can't reach this block
  # directly. See backend.hcl / backend-floci.hcl and terraform-state-backend/ for the source.
  backend "s3" {}
}

provider "aws" {
  region                      = var.aws_region
  access_key                  = var.use_floci ? "test" : null
  secret_key                  = var.use_floci ? "test" : null
  skip_credentials_validation = var.use_floci
  skip_metadata_api_check     = var.use_floci
  skip_requesting_account_id  = var.use_floci

  dynamic "endpoints" {
    for_each = var.use_floci ? [1] : []
    content {
      ec2 = "http://localhost:4566"
    }
  }
}
