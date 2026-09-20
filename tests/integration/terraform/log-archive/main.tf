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

variable "bucket_name" {
  type        = string
  description = "Synthetic local integration bucket name."
}

variable "organization_id" {
  type        = string
  description = "Organization ID from the integration organization state."
}

variable "management_account_id" {
  type        = string
  description = "Management account ID from the integration organization state."
}

variable "trail_name" {
  type        = string
  description = "Shared integration trail name."
}

variable "trail_home_region" {
  type        = string
  description = "Integration trail home Region."
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

module "log_archive" {
  source = "../../../../modules/log-archive"

  bucket_name           = var.bucket_name
  organization_id       = var.organization_id
  management_account_id = var.management_account_id
  trail_name            = var.trail_name
  trail_home_region     = var.trail_home_region

  tags = {
    Project   = "aws-multi-account-landing-zone"
    ManagedBy = "Terraform"
  }
}

output "bucket_name" {
  value = module.log_archive.bucket_name
}

output "bucket_arn" {
  value = module.log_archive.bucket_arn
}

output "kms_key_arn" {
  value = module.log_archive.kms_key_arn
}

output "kms_key_id" {
  value = module.log_archive.kms_key_id
}
