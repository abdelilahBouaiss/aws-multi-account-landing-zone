mock_provider "aws" {
  mock_resource "aws_organizations_policy" {
    defaults = {
      arn = "arn:aws:organizations::000000000000:policy/o-example/service_control_policy/p-example12345678"
      id  = "p-example12345678"
    }
  }

  mock_resource "aws_organizations_policy_attachment" {
    defaults = {
      id = "p-example12345678-target"
    }
  }
}

run "policy_without_attachments" {
  command = apply

  assert {
    condition     = aws_organizations_policy.protect_account_membership.type == "SERVICE_CONTROL_POLICY"
    error_message = "The policy must be an AWS Organizations service control policy."
  }

  assert {
    condition     = length(aws_organizations_policy_attachment.protect_account_membership) == 0
    error_message = "An empty attachment target map must create no policy attachments."
  }

  assert {
    condition     = jsondecode(aws_organizations_policy.protect_account_membership.content).Version == "2012-10-17"
    error_message = "The generated policy must use policy version 2012-10-17."
  }

  assert {
    condition     = length(jsondecode(aws_organizations_policy.protect_account_membership.content).Statement) == 1
    error_message = "The protect-account-membership policy must contain exactly one statement."
  }

  assert {
    condition     = jsondecode(aws_organizations_policy.protect_account_membership.content).Statement[0].Sid == "DenyAccountDepartureAndClosure"
    error_message = "The policy statement must use the approved stable SID."
  }

  assert {
    condition     = jsondecode(aws_organizations_policy.protect_account_membership.content).Statement[0].Effect == "Deny"
    error_message = "The policy statement must deny the protected actions."
  }

  assert {
    condition     = toset(jsondecode(aws_organizations_policy.protect_account_membership.content).Statement[0].Action) == toset(["organizations:LeaveOrganization", "account:CloseAccount"])
    error_message = "The policy must deny exactly the member-account departure and closure actions."
  }

  assert {
    condition     = jsondecode(aws_organizations_policy.protect_account_membership.content).Statement[0].Resource == "*"
    error_message = "The policy statement must apply to all resources."
  }

  assert {
    condition     = output.protect_account_membership_policy_id == aws_organizations_policy.protect_account_membership.id && output.protect_account_membership_policy_arn == aws_organizations_policy.protect_account_membership.arn
    error_message = "The policy ID and ARN outputs must expose the created SCP identifiers."
  }
}

run "policy_with_attachment_targets" {
  command = apply

  variables {
    attachment_targets = {
      organization_root = "r-example1234"
      policy_staging    = "ou-policy1-12345678"
      sandbox           = "ou-sandbox-12345678"
      account           = "123456789012"
    }
  }

  assert {
    condition     = length(aws_organizations_policy_attachment.protect_account_membership) == length(var.attachment_targets)
    error_message = "Each supplied attachment target must create one attachment resource."
  }

  assert {
    condition = alltrue([
      for label, attachment in aws_organizations_policy_attachment.protect_account_membership :
      attachment.policy_id == aws_organizations_policy.protect_account_membership.id &&
      attachment.target_id == var.attachment_targets[label]
    ])
    error_message = "Every attachment must reference this policy and its supplied target ID."
  }

  assert {
    condition     = toset([for attachment in aws_organizations_policy_attachment.protect_account_membership : attachment.target_id]) == toset(values(var.attachment_targets))
    error_message = "All supplied root, OU, and account target IDs must propagate to attachments."
  }
}

run "invalid_attachment_target_fails" {
  command = plan

  variables {
    attachment_targets = {
      invalid = "not-an-organizations-target"
    }
  }

  expect_failures = [var.attachment_targets]
}
