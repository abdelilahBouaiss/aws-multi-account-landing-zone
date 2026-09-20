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
  description = "The integration Log Archive bucket name."
}

variable "kms_key_arn" {
  type        = string
  description = "The integration Log Archive KMS key ARN."
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

module "cloudtrail" {
  source = "../../../../modules/cloudtrail"

  trail_name     = "org-audit-trail"
  s3_bucket_name = var.bucket_name
  kms_key_arn    = var.kms_key_arn
  home_region    = "eu-west-1"

  tags = {
    Project   = "aws-multi-account-landing-zone"
    ManagedBy = "Terraform"
  }
}

output "trail_name" {
  value = module.cloudtrail.trail_name
}

output "trail_arn" {
  value = module.cloudtrail.trail_arn
}
