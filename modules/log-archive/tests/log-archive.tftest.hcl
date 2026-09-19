mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "222222222222"
    }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::central-log-archive-example"
      id  = "central-log-archive-example"
    }
  }

  mock_resource "aws_kms_key" {
    defaults = {
      arn    = "arn:aws:kms:eu-west-1:222222222222:key/key-example"
      key_id = "key-example"
    }
  }

  mock_resource "aws_kms_alias" {
    defaults = {
      name = "alias/cloudtrail-log-archive"
    }
  }
}

run "baseline_without_retention" {
  command = apply

  variables {
    bucket_name           = "central-log-archive-example"
    organization_id       = "o-123456789012"
    management_account_id = "111111111111"
    trail_name            = "org-audit-trail"
  }

  assert {
    condition     = aws_s3_bucket.this.bucket == var.bucket_name
    error_message = "The S3 bucket must use the caller-supplied bucket name."
  }

  assert {
    condition     = aws_s3_bucket.this.force_destroy != true
    error_message = "The audit bucket must not enable destructive force_destroy behavior."
  }

  assert {
    condition = (
      aws_s3_bucket_public_access_block.this.block_public_acls &&
      aws_s3_bucket_public_access_block.this.ignore_public_acls &&
      aws_s3_bucket_public_access_block.this.block_public_policy &&
      aws_s3_bucket_public_access_block.this.restrict_public_buckets
    )
    error_message = "All S3 public-access protections must be enabled."
  }

  assert {
    condition     = one(aws_s3_bucket_ownership_controls.this.rule).object_ownership == "BucketOwnerEnforced"
    error_message = "The bucket must use BucketOwnerEnforced object ownership."
  }

  assert {
    condition     = one(aws_s3_bucket_versioning.this.versioning_configuration).status == "Enabled"
    error_message = "Bucket versioning must be enabled."
  }

  assert {
    condition = (
      one(one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default).sse_algorithm == "aws:kms" &&
      one(one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default).kms_master_key_id == aws_kms_key.cloudtrail_log_archive.arn &&
      one(aws_s3_bucket_server_side_encryption_configuration.this.rule).bucket_key_enabled == false
    )
    error_message = "Bucket encryption must use this module's KMS key with S3 Bucket Keys disabled."
  }

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.retention) == 0
    error_message = "A null retention_days input must create no expiration lifecycle rule."
  }

  assert {
    condition = (
      output.bucket_name == aws_s3_bucket.this.bucket &&
      output.bucket_arn == aws_s3_bucket.this.arn &&
      output.kms_key_id == aws_kms_key.cloudtrail_log_archive.key_id &&
      output.kms_key_arn == aws_kms_key.cloudtrail_log_archive.arn &&
      output.kms_alias_name == aws_kms_alias.cloudtrail_log_archive.name &&
      output.cloudtrail_log_prefix == "AWSLogs/o-123456789012/"
    )
    error_message = "Storage and CloudTrail prefix outputs must reference the expected resources and organization path."
  }

  assert {
    condition = (
      length(jsondecode(aws_s3_bucket_policy.cloudtrail.policy).Statement) == 2 &&
      toset([for statement in jsondecode(aws_s3_bucket_policy.cloudtrail.policy).Statement : statement.Sid]) == toset(["AWSCloudTrailAclCheck", "AWSCloudTrailWrite"])
    )
    error_message = "The bucket policy must contain exactly the ACL-check and organization-write statements."
  }

  assert {
    condition = alltrue([
      for statement in jsondecode(aws_s3_bucket_policy.cloudtrail.policy).Statement :
      toset(keys(statement.Principal)) == toset(["Service"]) &&
      statement.Principal.Service == "cloudtrail.amazonaws.com" &&
      statement.Principal != "*"
    ])
    error_message = "Only the CloudTrail service principal may appear in the bucket policy."
  }

  assert {
    condition     = toset([for statement in jsondecode(aws_s3_bucket_policy.cloudtrail.policy).Statement : statement.Action]) == toset(["s3:GetBucketAcl", "s3:PutObject"])
    error_message = "The bucket policy must grant exactly GetBucketAcl and PutObject to CloudTrail."
  }

  assert {
    condition = (
      jsondecode(aws_s3_bucket_policy.cloudtrail.policy).Statement[0].Resource == aws_s3_bucket.this.arn &&
      toset(keys(jsondecode(aws_s3_bucket_policy.cloudtrail.policy).Statement[0].Condition)) == toset(["StringEquals"]) &&
      toset(keys(jsondecode(aws_s3_bucket_policy.cloudtrail.policy).Statement[0].Condition.StringEquals)) == toset(["aws:SourceArn"]) &&
      jsondecode(aws_s3_bucket_policy.cloudtrail.policy).Statement[0].Condition.StringEquals["aws:SourceArn"] == "arn:aws:cloudtrail:eu-west-1:111111111111:trail/org-audit-trail"
    )
    error_message = "The ACL-check statement must target the bucket and exact management-account organization trail ARN."
  }

  assert {
    condition = (
      jsondecode(aws_s3_bucket_policy.cloudtrail.policy).Statement[1].Resource == "${aws_s3_bucket.this.arn}/AWSLogs/o-123456789012/*" &&
      toset(keys(jsondecode(aws_s3_bucket_policy.cloudtrail.policy).Statement[1].Condition)) == toset(["StringEquals"]) &&
      toset(keys(jsondecode(aws_s3_bucket_policy.cloudtrail.policy).Statement[1].Condition.StringEquals)) == toset(["aws:SourceArn", "s3:x-amz-acl"]) &&
      jsondecode(aws_s3_bucket_policy.cloudtrail.policy).Statement[1].Condition.StringEquals["aws:SourceArn"] == "arn:aws:cloudtrail:eu-west-1:111111111111:trail/org-audit-trail" &&
      jsondecode(aws_s3_bucket_policy.cloudtrail.policy).Statement[1].Condition.StringEquals["s3:x-amz-acl"] == "bucket-owner-full-control"
    )
    error_message = "The organization write statement must use the organization path, exact SourceArn, and bucket-owner-full-control ACL condition."
  }

  assert {
    condition = alltrue([
      for action in ["s3:GetObject", "s3:ListBucket", "s3:DeleteObject", "s3:PutBucketPolicy"] :
      !contains([for statement in jsondecode(aws_s3_bucket_policy.cloudtrail.policy).Statement : statement.Action], action)
    ])
    error_message = "The CloudTrail bucket policy must not grant read, delete, listing, or bucket-policy mutation access."
  }

  assert {
    condition = (
      aws_kms_key.cloudtrail_log_archive.enable_key_rotation &&
      aws_kms_key.cloudtrail_log_archive.deletion_window_in_days == 30 &&
      aws_kms_key.cloudtrail_log_archive.customer_master_key_spec == "SYMMETRIC_DEFAULT" &&
      aws_kms_key.cloudtrail_log_archive.key_usage == "ENCRYPT_DECRYPT"
    )
    error_message = "The KMS key must be a rotating symmetric customer-managed encryption key with a 30-day deletion window."
  }

  assert {
    condition = (
      length(jsondecode(aws_kms_key.cloudtrail_log_archive.policy).Statement) == 3 &&
      toset([for statement in jsondecode(aws_kms_key.cloudtrail_log_archive.policy).Statement : statement.Sid]) == toset(["EnableLogArchiveAccountAdministration", "AllowCloudTrailEncryptLogs", "AllowCloudTrailDescribeKey"])
    )
    error_message = "The KMS policy must contain only account administration, CloudTrail encryption, and CloudTrail DescribeKey statements."
  }

  assert {
    condition = (
      jsondecode(aws_kms_key.cloudtrail_log_archive.policy).Statement[0].Principal.AWS == "arn:aws:iam::222222222222:root" &&
      jsondecode(aws_kms_key.cloudtrail_log_archive.policy).Statement[0].Action == "kms:*" &&
      !strcontains(jsonencode(jsondecode(aws_kms_key.cloudtrail_log_archive.policy).Statement[0]), "111111111111")
    )
    error_message = "KMS administration must be tied to the Log Archive account identity, not the management account."
  }

  assert {
    condition = (
      jsondecode(aws_kms_key.cloudtrail_log_archive.policy).Statement[1].Principal.Service == "cloudtrail.amazonaws.com" &&
      jsondecode(aws_kms_key.cloudtrail_log_archive.policy).Statement[1].Action == "kms:GenerateDataKey*" &&
      toset(keys(jsondecode(aws_kms_key.cloudtrail_log_archive.policy).Statement[1].Condition)) == toset(["StringEquals", "StringLike"]) &&
      jsondecode(aws_kms_key.cloudtrail_log_archive.policy).Statement[1].Condition.StringEquals["aws:SourceArn"] == "arn:aws:cloudtrail:eu-west-1:111111111111:trail/org-audit-trail" &&
      toset(keys(jsondecode(aws_kms_key.cloudtrail_log_archive.policy).Statement[1].Condition.StringEquals)) == toset(["aws:SourceArn"]) &&
      toset(keys(jsondecode(aws_kms_key.cloudtrail_log_archive.policy).Statement[1].Condition.StringLike)) == toset(["kms:EncryptionContext:aws:cloudtrail:arn"]) &&
      jsondecode(aws_kms_key.cloudtrail_log_archive.policy).Statement[1].Condition.StringLike["kms:EncryptionContext:aws:cloudtrail:arn"] == "arn:aws:cloudtrail:*:111111111111:trail/*"
    )
    error_message = "CloudTrail GenerateDataKey must use the exact SourceArn and multi-Region encryption-context pattern."
  }

  assert {
    condition = (
      jsondecode(aws_kms_key.cloudtrail_log_archive.policy).Statement[2].Principal.Service == "cloudtrail.amazonaws.com" &&
      jsondecode(aws_kms_key.cloudtrail_log_archive.policy).Statement[2].Action == "kms:DescribeKey" &&
      toset(keys(jsondecode(aws_kms_key.cloudtrail_log_archive.policy).Statement[2].Condition)) == toset(["StringEquals"]) &&
      toset(keys(jsondecode(aws_kms_key.cloudtrail_log_archive.policy).Statement[2].Condition.StringEquals)) == toset(["aws:SourceArn"]) &&
      jsondecode(aws_kms_key.cloudtrail_log_archive.policy).Statement[2].Condition.StringEquals["aws:SourceArn"] == "arn:aws:cloudtrail:eu-west-1:111111111111:trail/org-audit-trail" &&
      !contains(keys(jsondecode(aws_kms_key.cloudtrail_log_archive.policy).Statement[2].Condition), "StringLike") &&
      !contains(keys(jsondecode(aws_kms_key.cloudtrail_log_archive.policy).Statement[2].Condition.StringEquals), "kms:EncryptionContext:aws:cloudtrail:arn")
    )
    error_message = "CloudTrail DescribeKey must use only the exact SourceArn condition without an encryption-context condition."
  }

  assert {
    condition = alltrue([
      for action in [
        jsondecode(aws_kms_key.cloudtrail_log_archive.policy).Statement[1].Action,
        jsondecode(aws_kms_key.cloudtrail_log_archive.policy).Statement[2].Action,
      ] :
      action != "kms:Decrypt"
    ])
    error_message = "CloudTrail service grants must not include kms:Decrypt."
  }
}

run "configured_retention" {
  command = apply

  variables {
    bucket_name           = "central-log-archive-example"
    organization_id       = "o-123456789012"
    management_account_id = "111111111111"
    trail_name            = "org-audit-trail"
    retention_days        = 365
  }

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.retention) == 1
    error_message = "A configured retention_days input must create one lifecycle configuration."
  }

  assert {
    condition = (
      one(aws_s3_bucket_lifecycle_configuration.retention["configured"].rule).status == "Enabled" &&
      one(one(aws_s3_bucket_lifecycle_configuration.retention["configured"].rule).expiration).days == var.retention_days
    )
    error_message = "The lifecycle rule must expire objects after the configured positive whole-number retention period."
  }
}

run "invalid_organization_id_fails" {
  command = plan

  variables {
    bucket_name           = "central-log-archive-example"
    organization_id       = "invalid-organization"
    management_account_id = "111111111111"
    trail_name            = "org-audit-trail"
  }

  expect_failures = [var.organization_id]
}

run "invalid_management_account_id_fails" {
  command = plan

  variables {
    bucket_name           = "central-log-archive-example"
    organization_id       = "o-123456789012"
    management_account_id = "12345"
    trail_name            = "org-audit-trail"
  }

  expect_failures = [var.management_account_id]
}

run "invalid_bucket_name_fails" {
  command = plan

  variables {
    bucket_name           = "Invalid Bucket"
    organization_id       = "o-123456789012"
    management_account_id = "111111111111"
    trail_name            = "org-audit-trail"
  }

  expect_failures = [var.bucket_name]
}

run "invalid_region_fails" {
  command = plan

  variables {
    bucket_name           = "central-log-archive-example"
    organization_id       = "o-123456789012"
    management_account_id = "111111111111"
    trail_name            = "org-audit-trail"
    trail_home_region     = "us-east-1"
  }

  expect_failures = [var.trail_home_region]
}

run "invalid_retention_days_fails" {
  command = plan

  variables {
    bucket_name           = "central-log-archive-example"
    organization_id       = "o-123456789012"
    management_account_id = "111111111111"
    trail_name            = "org-audit-trail"
    retention_days        = 0
  }

  expect_failures = [var.retention_days]
}
