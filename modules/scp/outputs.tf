output "protect_account_membership_policy_id" {
  description = "The ID of the protect-account-membership service control policy."
  value       = aws_organizations_policy.protect_account_membership.id
}

output "protect_account_membership_policy_arn" {
  description = "The ARN of the protect-account-membership service control policy."
  value       = aws_organizations_policy.protect_account_membership.arn
}

output "restrict_regions_policy_id" {
  description = "The ID of the restrict-regions service control policy."
  value       = aws_organizations_policy.restrict_regions.id
}

output "restrict_regions_policy_arn" {
  description = "The ARN of the restrict-regions service control policy."
  value       = aws_organizations_policy.restrict_regions.arn
}

output "protect_cloudtrail_policy_id" {
  description = "The ID of the protect-cloudtrail service control policy."
  value       = aws_organizations_policy.protect_cloudtrail.id
}

output "protect_cloudtrail_policy_arn" {
  description = "The ARN of the protect-cloudtrail service control policy."
  value       = aws_organizations_policy.protect_cloudtrail.arn
}
