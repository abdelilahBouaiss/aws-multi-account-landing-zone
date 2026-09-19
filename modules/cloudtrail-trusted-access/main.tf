resource "aws_organizations_aws_service_access" "cloudtrail" {
  service_principal = "cloudtrail.amazonaws.com"
}
