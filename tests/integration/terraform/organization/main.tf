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

module "organization" {
  source = "../../../../modules/organization"

  tags = {
    Project   = "aws-multi-account-landing-zone"
    ManagedBy = "Terraform"
  }
}

output "organization_id" {
  value = module.organization.organization_id
}

output "management_account_id" {
  value = module.organization.management_account_id
}

output "root_id" {
  value = module.organization.root_id
}

output "top_level_ou_ids" {
  value = module.organization.top_level_ou_ids
}

output "workload_ou_ids" {
  value = module.organization.workload_ou_ids
}
