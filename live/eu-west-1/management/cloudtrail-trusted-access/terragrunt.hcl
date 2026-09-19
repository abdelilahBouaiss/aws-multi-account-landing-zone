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

dependencies {
  paths = ["../organization"]
}

terraform {
  source = "../../../../modules/cloudtrail-trusted-access"
}

inputs = {}
