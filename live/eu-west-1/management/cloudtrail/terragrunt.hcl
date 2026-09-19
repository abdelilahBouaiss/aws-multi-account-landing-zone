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

dependency "storage" {
  config_path = "../../log-archive/cloudtrail-storage"

  mock_outputs = {
    bucket_name = "portfolio-cloudtrail-validation-only"
    kms_key_arn = "arn:aws:kms:eu-west-1:111111111111:key/00000000-0000-0000-0000-000000000000"
  }

  mock_outputs_allowed_terraform_commands = ["validate"]
}

dependencies {
  paths = [
    "../cloudtrail-trusted-access",
    "../cloudtrail-bootstrap",
  ]
}

terraform {
  source = "../../../../modules/cloudtrail"
}

inputs = {
  trail_name     = "org-audit-trail"
  s3_bucket_name = dependency.storage.outputs.bucket_name
  kms_key_arn    = dependency.storage.outputs.kms_key_arn
  home_region    = include.region.locals.aws_region
  tags = {
    Project   = "aws-multi-account-landing-zone"
    ManagedBy = "Terraform"
  }
}
