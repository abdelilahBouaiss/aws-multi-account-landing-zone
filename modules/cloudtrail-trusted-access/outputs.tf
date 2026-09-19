output "service_principal" {
  description = "The AWS service principal for which Organizations trusted access is enabled."
  value       = aws_organizations_aws_service_access.cloudtrail.service_principal
}
