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

variable "top_level_ou_ids" {
  type        = map(string)
  description = "Top-level OU IDs from the integration organization state."
}

variable "workload_ou_ids" {
  type        = map(string)
  description = "Nested workload OU IDs from the integration organization state."
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

module "account_vending" {
  source = "../../../../modules/account-vending"

  common_tags = {
    Project   = "aws-multi-account-landing-zone"
    ManagedBy = "Terraform"
  }

  accounts = {
    security_tooling = {
      name      = "Security Tooling"
      email     = "security-tooling@example.com"
      parent_id = var.top_level_ou_ids.security
    }

    log_archive = {
      name      = "Log Archive"
      email     = "log-archive@example.com"
      parent_id = var.top_level_ou_ids.security
    }

    shared_services = {
      name      = "Shared Services"
      email     = "shared-services@example.com"
      parent_id = var.top_level_ou_ids.infrastructure
    }

    development = {
      name      = "Development"
      email     = "development@example.com"
      parent_id = var.workload_ou_ids.non_production
    }

    staging = {
      name      = "Staging"
      email     = "staging@example.com"
      parent_id = var.workload_ou_ids.non_production
    }

    production = {
      name      = "Production"
      email     = "production@example.com"
      parent_id = var.workload_ou_ids.production
    }

    sandbox = {
      name      = "Sandbox"
      email     = "sandbox@example.com"
      parent_id = var.top_level_ou_ids.sandbox
    }

    policy_test = {
      name      = "Policy Test"
      email     = "policy-test@example.com"
      parent_id = var.top_level_ou_ids.policy_staging
    }
  }
}

output "account_ids" {
  value = module.account_vending.account_ids
}
