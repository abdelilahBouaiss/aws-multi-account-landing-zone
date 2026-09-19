data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

locals {
  trail_arn             = "arn:${data.aws_partition.current.partition}:cloudtrail:${var.trail_home_region}:${var.management_account_id}:trail/${var.trail_name}"
  cloudtrail_log_prefix = "AWSLogs/${var.organization_id}/"
  log_object_resource   = "${aws_s3_bucket.this.arn}/${local.cloudtrail_log_prefix}*"

  bucket_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.this.arn
        Condition = {
          StringEquals = {
            "aws:SourceArn" = local.trail_arn
          }
        }
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = local.log_object_resource
        Condition = {
          StringEquals = {
            "aws:SourceArn" = local.trail_arn
            "s3:x-amz-acl"  = "bucket-owner-full-control"
          }
        }
      }
    ]
  }

  kms_key_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableLogArchiveAccountAdministration"
        Effect    = "Allow"
        Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowCloudTrailEncryptLogs"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "kms:GenerateDataKey*"
        Resource  = "*"
        Condition = {
          StringEquals = {
            "aws:SourceArn" = local.trail_arn
          }
          StringLike = {
            "kms:EncryptionContext:aws:cloudtrail:arn" = "arn:${data.aws_partition.current.partition}:cloudtrail:*:${var.management_account_id}:trail/*"
          }
        }
      },
      {
        Sid       = "AllowCloudTrailDescribeKey"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "kms:DescribeKey"
        Resource  = "*"
        Condition = {
          StringEquals = {
            "aws:SourceArn" = local.trail_arn
          }
        }
      }
    ]
  }
}

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.cloudtrail_log_archive.arn
      sse_algorithm     = "aws:kms"
    }

    bucket_key_enabled = false
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "retention" {
  for_each = var.retention_days == null ? {} : { configured = var.retention_days }

  bucket = aws_s3_bucket.this.id

  rule {
    id     = "configured-retention"
    status = "Enabled"

    filter {}

    expiration {
      days = each.value
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.this.id
  policy = jsonencode(local.bucket_policy)
}

resource "aws_kms_key" "cloudtrail_log_archive" {
  description              = "Customer-managed key for centralized CloudTrail log archive encryption."
  deletion_window_in_days  = 30
  enable_key_rotation      = true
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  key_usage                = "ENCRYPT_DECRYPT"
  policy                   = jsonencode(local.kms_key_policy)
  tags                     = var.tags
}

resource "aws_kms_alias" "cloudtrail_log_archive" {
  name          = "alias/cloudtrail-log-archive"
  target_key_id = aws_kms_key.cloudtrail_log_archive.key_id
}
