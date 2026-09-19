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

dependency "accounts" {
  config_path = "../accounts"

  mock_outputs = {
    account_ids = {
      security_tooling = "333333333333"
      log_archive      = "444444444444"
    }
  }

  mock_outputs_allowed_terraform_commands = ["validate"]
}

dependencies {
  paths = ["../cloudtrail-trusted-access"]
}

terraform {
  source = "../../../../modules/cloudtrail-bootstrap"
}

inputs = {
  security_tooling_account_id = dependency.accounts.outputs.account_ids.security_tooling
}
