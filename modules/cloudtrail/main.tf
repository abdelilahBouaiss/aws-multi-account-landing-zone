data "aws_region" "current" {}

resource "aws_cloudtrail" "organization" {
  name                          = var.trail_name
  s3_bucket_name                = var.s3_bucket_name
  kms_key_id                    = var.kms_key_arn
  is_organization_trail         = true
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  enable_logging                = true
  tags                          = var.tags

  lifecycle {
    precondition {
      condition     = data.aws_region.current.region == var.home_region
      error_message = "The AWS provider Region must match home_region (eu-west-1) for the organization CloudTrail."
    }
  }

  event_selector {
    include_management_events = true
    read_write_type           = "All"
  }
}
