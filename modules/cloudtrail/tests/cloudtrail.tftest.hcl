mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "eu-west-1"
    }
  }

  mock_resource "aws_cloudtrail" {
    defaults = {
      arn = "arn:aws:cloudtrail:eu-west-1:111111111111:trail/org-audit-trail"
      id  = "arn:aws:cloudtrail:eu-west-1:111111111111:trail/org-audit-trail"
    }
  }
}

variables {
  trail_name     = "org-audit-trail"
  s3_bucket_name = "central-log-archive-example"
  kms_key_arn    = "arn:aws:kms:eu-west-1:222222222222:key/12345678-1234-1234-1234-123456789012"
}

run "approved_organization_trail" {
  command = apply

  variables {
    tags = {
      Project     = "landing-zone"
      Environment = "security"
      ManagedBy   = "Terraform"
      Owner       = "platform"
      CostCenter  = "security"
    }
  }

  assert {
    condition     = aws_cloudtrail.organization.name == var.trail_name
    error_message = "The module must create the configured organization trail name."
  }

  assert {
    condition = (
      aws_cloudtrail.organization.s3_bucket_name == var.s3_bucket_name &&
      aws_cloudtrail.organization.kms_key_id == var.kms_key_arn
    )
    error_message = "The trail must use the supplied external Log Archive bucket and KMS key ARN."
  }

  assert {
    condition = (
      aws_cloudtrail.organization.is_organization_trail &&
      aws_cloudtrail.organization.is_multi_region_trail &&
      aws_cloudtrail.organization.include_global_service_events &&
      aws_cloudtrail.organization.enable_log_file_validation &&
      aws_cloudtrail.organization.enable_logging
    )
    error_message = "The trail must enable organization scope, multi-Region coverage, global events, log validation, and logging."
  }

  assert {
    condition = (
      length(aws_cloudtrail.organization.event_selector) == 1 &&
      one(aws_cloudtrail.organization.event_selector).include_management_events &&
      one(aws_cloudtrail.organization.event_selector).read_write_type == "All" &&
      length(one(aws_cloudtrail.organization.event_selector).data_resource) == 0
    )
    error_message = "The trail must have exactly one read/write management-event selector with no data events."
  }

  assert {
    condition = (
      length(aws_cloudtrail.organization.insight_selector) == 0 &&
      length(aws_cloudtrail.organization.advanced_event_selector) == 0
    )
    error_message = "The v1 trail must not configure Insights or advanced/data-event selectors."
  }

  assert {
    condition = (
      try(trimspace(aws_cloudtrail.organization.cloud_watch_logs_group_arn), "") == "" &&
      try(trimspace(aws_cloudtrail.organization.cloud_watch_logs_role_arn), "") == "" &&
      try(trimspace(aws_cloudtrail.organization.sns_topic_name), "") == "" &&
      try(trimspace(aws_cloudtrail.organization.s3_key_prefix), "") == ""
    )
    error_message = "The v1 trail must not configure CloudWatch Logs, SNS, or an S3 key prefix."
  }

  assert {
    condition = (
      output.trail_id == aws_cloudtrail.organization.id &&
      output.trail_arn == aws_cloudtrail.organization.arn &&
      output.trail_name == aws_cloudtrail.organization.name &&
      data.aws_region.current.region == "eu-west-1" &&
      data.aws_region.current.region == var.home_region &&
      output.trail_home_region == data.aws_region.current.region &&
      output.is_organization_trail == aws_cloudtrail.organization.is_organization_trail
    )
    error_message = "Outputs must reference the configured organization trail and approved home Region."
  }
}

run "provider_region_mismatch_fails" {
  command = plan

  override_data {
    target = data.aws_region.current
    values = {
      region = "us-east-1"
    }
  }

  expect_failures = [aws_cloudtrail.organization]
}

run "invalid_trail_name_fails" {
  command = plan

  variables {
    trail_name = "invalid trail name"
  }

  expect_failures = [var.trail_name]
}

run "invalid_bucket_name_fails" {
  command = plan

  variables {
    s3_bucket_name = "Invalid Bucket"
  }

  expect_failures = [var.s3_bucket_name]
}

run "invalid_kms_key_arn_fails" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:eu-west-1:222222222222:alias/cloudtrail-log-archive"
  }

  expect_failures = [var.kms_key_arn]
}

run "invalid_home_region_fails" {
  command = plan

  variables {
    home_region = "us-east-1"
  }

  expect_failures = [var.home_region]
}
