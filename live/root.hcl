# Common composition settings shared by future live units.
# Provider generation reads the Region contract relative to the original unit.

locals {
  region_config = read_terragrunt_config(
    "${get_original_terragrunt_dir()}/../../region.hcl"
  )
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<-EOF
    provider "aws" {
      region = "${local.region_config.locals.aws_region}"
    }
  EOF
}
