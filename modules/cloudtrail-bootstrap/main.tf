resource "aws_cloudtrail_organization_delegated_admin_account" "security_tooling" {
  account_id = var.security_tooling_account_id
}
