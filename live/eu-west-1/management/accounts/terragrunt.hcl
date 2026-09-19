include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "region" {
  path   = find_in_parent_folders("region.hcl")
  expose = true
}

include "account" {
  path   = find_in_parent_folders("account.hcl")
  expose = true
}

dependency "organization" {
  config_path = "../organization"

  mock_outputs = {
    top_level_ou_ids = {
      security       = "ou-fake0-00000000"
      infrastructure = "ou-fake1-11111111"
      workloads      = "ou-fake2-22222222"
      sandbox        = "ou-fake3-33333333"
      policy_staging = "ou-fake4-44444444"
    }

    workload_ou_ids = {
      non_production = "ou-fake5-55555555"
      production     = "ou-fake6-66666666"
    }
  }

  mock_outputs_allowed_terraform_commands = ["validate"]
}

terraform {
  source = "../../../../modules/account-vending"
}

inputs = {
  common_tags = {
    Project   = "aws-multi-account-landing-zone"
    ManagedBy = "Terraform"
  }

  accounts = {
    security_tooling = {
      name      = "Security Tooling"
      email     = get_env("AWS_ACCOUNT_EMAIL_SECURITY_TOOLING")
      parent_id = dependency.organization.outputs.top_level_ou_ids.security
    }

    log_archive = {
      name      = "Log Archive"
      email     = get_env("AWS_ACCOUNT_EMAIL_LOG_ARCHIVE")
      parent_id = dependency.organization.outputs.top_level_ou_ids.security
    }

    shared_services = {
      name      = "Shared Services"
      email     = get_env("AWS_ACCOUNT_EMAIL_SHARED_SERVICES")
      parent_id = dependency.organization.outputs.top_level_ou_ids.infrastructure
    }

    development = {
      name      = "Development"
      email     = get_env("AWS_ACCOUNT_EMAIL_DEVELOPMENT")
      parent_id = dependency.organization.outputs.workload_ou_ids.non_production
    }

    staging = {
      name      = "Staging"
      email     = get_env("AWS_ACCOUNT_EMAIL_STAGING")
      parent_id = dependency.organization.outputs.workload_ou_ids.non_production
    }

    production = {
      name      = "Production"
      email     = get_env("AWS_ACCOUNT_EMAIL_PRODUCTION")
      parent_id = dependency.organization.outputs.workload_ou_ids.production
    }

    sandbox = {
      name      = "Sandbox"
      email     = get_env("AWS_ACCOUNT_EMAIL_SANDBOX")
      parent_id = dependency.organization.outputs.top_level_ou_ids.sandbox
    }

    policy_test = {
      name      = "Policy Test"
      email     = get_env("AWS_ACCOUNT_EMAIL_POLICY_TEST")
      parent_id = dependency.organization.outputs.top_level_ou_ids.policy_staging
    }
  }
}
