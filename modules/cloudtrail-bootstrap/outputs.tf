output "delegated_admin_account_id" {
  description = "The account ID registered as the CloudTrail delegated administrator."
  value       = aws_cloudtrail_organization_delegated_admin_account.security_tooling.account_id
}

output "delegated_admin_arn" {
  description = "The ARN reported for the CloudTrail delegated administrator registration."
  value       = aws_cloudtrail_organization_delegated_admin_account.security_tooling.arn
}

output "service_principal" {
  description = "The CloudTrail service principal associated with the delegated administrator registration."
  value       = aws_cloudtrail_organization_delegated_admin_account.security_tooling.service_principal
}
