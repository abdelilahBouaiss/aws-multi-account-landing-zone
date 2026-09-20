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

variable "policy_staging_ou_id" {
  type        = string
  description = "The limited integration attachment target."
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

module "scp" {
  source = "../../../../modules/scp"

  attachment_targets = {
    policy_staging = var.policy_staging_ou_id
  }

  restrict_regions_attachment_targets = {
    policy_staging = var.policy_staging_ou_id
  }

  protect_cloudtrail_attachment_targets = {
    policy_staging = var.policy_staging_ou_id
  }

  protect_security_services_attachment_targets = {
    policy_staging = var.policy_staging_ou_id
  }

  restrict_member_root_user_attachment_targets = {
    policy_staging = var.policy_staging_ou_id
  }
}

output "policy_ids" {
  value = {
    protect_account_membership = module.scp.protect_account_membership_policy_id
    restrict_regions           = module.scp.restrict_regions_policy_id
    protect_cloudtrail         = module.scp.protect_cloudtrail_policy_id
    protect_security_services  = module.scp.protect_security_services_policy_id
    restrict_member_root_user  = module.scp.restrict_member_root_user_policy_id
  }
}
