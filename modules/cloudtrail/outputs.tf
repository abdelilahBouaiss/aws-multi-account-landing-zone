output "trail_id" {
  description = "The ID of the organization CloudTrail trail."
  value       = aws_cloudtrail.organization.id
}

output "trail_arn" {
  description = "The ARN of the organization CloudTrail trail."
  value       = aws_cloudtrail.organization.arn
}

output "trail_name" {
  description = "The configured name of the organization CloudTrail trail."
  value       = aws_cloudtrail.organization.name
}

output "trail_home_region" {
  description = "The approved home Region for the organization CloudTrail trail."
  value       = data.aws_region.current.region
}

output "is_organization_trail" {
  description = "Whether the trail is configured as an AWS Organizations trail."
  value       = aws_cloudtrail.organization.is_organization_trail
}
