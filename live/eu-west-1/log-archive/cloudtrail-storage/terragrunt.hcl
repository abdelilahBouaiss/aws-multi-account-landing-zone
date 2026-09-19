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
  config_path = "../../management/organization"

  mock_outputs = {
    organization_id       = "o-fake1234567890"
    management_account_id = "111111111111"
  }

  mock_outputs_allowed_terraform_commands = ["validate"]
}

terraform {
  source = "../../../../modules/log-archive"
}

inputs = {
  bucket_name           = get_env("AWS_CLOUDTRAIL_LOG_BUCKET_NAME")
  organization_id       = dependency.organization.outputs.organization_id
  management_account_id = dependency.organization.outputs.management_account_id
  trail_name            = "org-audit-trail"
  trail_home_region     = include.region.locals.aws_region
  tags = {
    Project   = "aws-multi-account-landing-zone"
    ManagedBy = "Terraform"
  }
}
