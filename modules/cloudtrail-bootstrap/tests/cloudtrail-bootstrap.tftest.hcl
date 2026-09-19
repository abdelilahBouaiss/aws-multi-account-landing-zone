mock_provider "aws" {
  mock_resource "aws_cloudtrail_organization_delegated_admin_account" {
    defaults = {
      arn               = "arn:aws:cloudtrail:eu-west-1:333333333333:organization-delegated-admin-account"
      service_principal = "cloudtrail.amazonaws.com"
    }
  }
}

variables {
  security_tooling_account_id = "333333333333"
}

run "register_security_tooling_delegated_admin" {
  command = apply

  assert {
    condition     = aws_cloudtrail_organization_delegated_admin_account.security_tooling.account_id == var.security_tooling_account_id
    error_message = "The CloudTrail delegated administrator must use the supplied Security Tooling account ID."
  }

  assert {
    condition = (
      output.delegated_admin_account_id == aws_cloudtrail_organization_delegated_admin_account.security_tooling.account_id &&
      output.delegated_admin_arn == aws_cloudtrail_organization_delegated_admin_account.security_tooling.arn &&
      output.service_principal == aws_cloudtrail_organization_delegated_admin_account.security_tooling.service_principal
    )
    error_message = "Outputs must reference the CloudTrail delegated administrator resource."
  }

  assert {
    condition     = aws_cloudtrail_organization_delegated_admin_account.security_tooling.service_principal == "cloudtrail.amazonaws.com"
    error_message = "The delegated administrator resource must resolve to the CloudTrail service principal."
  }
}

run "invalid_security_tooling_account_id_fails" {
  command = plan

  variables {
    security_tooling_account_id = "not-an-account-id"
  }

  expect_failures = [var.security_tooling_account_id]
}
