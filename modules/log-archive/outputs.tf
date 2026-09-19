output "bucket_name" {
  description = "The name of the centralized CloudTrail S3 bucket."
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "The ARN of the centralized CloudTrail S3 bucket."
  value       = aws_s3_bucket.this.arn
}

output "kms_key_id" {
  description = "The ID of the customer-managed KMS key used for CloudTrail encryption."
  value       = aws_kms_key.cloudtrail_log_archive.key_id
}

output "kms_key_arn" {
  description = "The ARN of the customer-managed KMS key used for CloudTrail encryption."
  value       = aws_kms_key.cloudtrail_log_archive.arn
}

output "kms_alias_name" {
  description = "The alias name of the customer-managed CloudTrail encryption key."
  value       = aws_kms_alias.cloudtrail_log_archive.name
}

output "cloudtrail_log_prefix" {
  description = "The organization CloudTrail S3 object prefix."
  value       = local.cloudtrail_log_prefix
}
