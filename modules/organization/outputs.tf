output "organization_id" {
  description = "The ID of the AWS Organization."
  value       = aws_organizations_organization.this.id
}

output "organization_arn" {
  description = "The ARN of the AWS Organization."
  value       = aws_organizations_organization.this.arn
}

output "root_id" {
  description = "The ID of the AWS Organizations root that contains the member-account OUs."
  value       = aws_organizations_organization.this.roots[0].id
}

output "top_level_ou_ids" {
  description = "Map of approved top-level OU keys to their AWS Organizations OU IDs."
  value = {
    for key, organizational_unit in aws_organizations_organizational_unit.top_level :
    key => organizational_unit.id
  }
}

output "workload_ou_ids" {
  description = "Map of workload OU keys to their AWS Organizations OU IDs."
  value = {
    for key, organizational_unit in aws_organizations_organizational_unit.workload :
    key => organizational_unit.id
  }
}
