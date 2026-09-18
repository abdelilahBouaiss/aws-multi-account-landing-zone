output "protect_account_membership_policy_id" {
  description = "The ID of the protect-account-membership service control policy."
  value       = aws_organizations_policy.protect_account_membership.id
}

output "protect_account_membership_policy_arn" {
  description = "The ARN of the protect-account-membership service control policy."
  value       = aws_organizations_policy.protect_account_membership.arn
}
