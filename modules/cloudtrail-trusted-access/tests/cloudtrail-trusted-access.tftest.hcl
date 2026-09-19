mock_provider "aws" {
  mock_resource "aws_organizations_aws_service_access" {
    defaults = {
      service_principal = "cloudtrail.amazonaws.com"
    }
  }
}

run "enable_cloudtrail_trusted_access" {
  command = apply

  assert {
    condition     = aws_organizations_aws_service_access.cloudtrail.service_principal == "cloudtrail.amazonaws.com"
    error_message = "The module must enable trusted access only for the CloudTrail service principal."
  }

  assert {
    condition     = output.service_principal == aws_organizations_aws_service_access.cloudtrail.service_principal
    error_message = "The service_principal output must reference the trusted-access resource."
  }
}
