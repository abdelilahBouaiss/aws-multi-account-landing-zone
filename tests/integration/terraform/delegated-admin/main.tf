terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

variable "endpoint" {
  type        = string
  description = "The integration-only AWS-compatible endpoint."

  validation {
    condition     = var.endpoint == "http://localhost:4566"
    error_message = "Integration endpoint must be exactly http://localhost:4566."
  }
}

variable "security_tooling_account_id" {
  type        = string
  description = "The synthetic local Security Tooling account ID from account vending."
}

provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = "eu-west-1"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    account       = var.endpoint
    cloudtrail    = var.endpoint
    iam           = var.endpoint
    kms           = var.endpoint
    organizations = var.endpoint
    s3            = var.endpoint
    sts           = var.endpoint
  }
}

module "delegated_admin" {
  source = "../../../../modules/cloudtrail-bootstrap"

  security_tooling_account_id = var.security_tooling_account_id
}

output "delegated_admin_account_id" {
  value = module.delegated_admin.delegated_admin_account_id
}

output "service_principal" {
  value = module.delegated_admin.service_principal
}
