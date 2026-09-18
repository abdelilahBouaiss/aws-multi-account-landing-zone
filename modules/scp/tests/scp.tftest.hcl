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
    condition     = aws_organizations_policy.restrict_regions.type == "SERVICE_CONTROL_POLICY"
    error_message = "The restrict-regions policy must be an AWS Organizations service control policy."
  }

  assert {
    condition     = length(aws_organizations_policy_attachment.protect_account_membership) == 0
    error_message = "An empty attachment target map must create no policy attachments."
  }

  assert {
    condition     = length(aws_organizations_policy_attachment.restrict_regions) == 0
    error_message = "An empty restrict-regions attachment target map must create no policy attachments."
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

  assert {
    condition     = output.restrict_regions_policy_id == aws_organizations_policy.restrict_regions.id && output.restrict_regions_policy_arn == aws_organizations_policy.restrict_regions.arn
    error_message = "The restrict-regions policy ID and ARN outputs must expose the correct policy identifiers."
  }

  assert {
    condition     = jsondecode(aws_organizations_policy.restrict_regions.content).Version == "2012-10-17"
    error_message = "The restrict-regions policy must use policy version 2012-10-17."
  }

  assert {
    condition     = length(jsondecode(aws_organizations_policy.restrict_regions.content).Statement) == 1
    error_message = "The restrict-regions policy must contain exactly one statement."
  }

  assert {
    condition     = jsondecode(aws_organizations_policy.restrict_regions.content).Statement[0].Sid == "DenyOutsideApprovedRegion"
    error_message = "The restrict-regions statement must use the approved stable SID."
  }

  assert {
    condition     = jsondecode(aws_organizations_policy.restrict_regions.content).Statement[0].Effect == "Deny" && jsondecode(aws_organizations_policy.restrict_regions.content).Statement[0].Resource == "*"
    error_message = "The restrict-regions statement must deny all resources."
  }

  assert {
    condition     = toset(jsondecode(aws_organizations_policy.restrict_regions.content).Statement[0].NotAction) == toset(["cloudfront:*", "iam:*", "route53:*", "support:*", "organizations:*", "budgets:*", "sts:*"])
    error_message = "The restrict-regions statement must use exactly the approved global-service NotAction exceptions."
  }

  assert {
    condition     = !contains(keys(jsondecode(aws_organizations_policy.restrict_regions.content).Statement[0]), "Action")
    error_message = "The restrict-regions statement must use NotAction and must not contain Action."
  }

  assert {
    condition = (
      toset(keys(jsondecode(aws_organizations_policy.restrict_regions.content).Statement[0].Condition)) == toset(["StringNotEquals"]) &&
      toset(keys(jsondecode(aws_organizations_policy.restrict_regions.content).Statement[0].Condition.StringNotEquals)) == toset(["aws:RequestedRegion"]) &&
      length(jsondecode(aws_organizations_policy.restrict_regions.content).Statement[0].Condition.StringNotEquals["aws:RequestedRegion"]) == 1 &&
      jsondecode(aws_organizations_policy.restrict_regions.content).Statement[0].Condition.StringNotEquals["aws:RequestedRegion"][0] == "eu-west-1"
    )
    error_message = "The restrict-regions condition must deny requests outside exactly eu-west-1."
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

  assert {
    condition     = length(aws_organizations_policy_attachment.restrict_regions) == 0
    error_message = "Protect-account-membership attachments must not create restrict-regions attachments."
  }
}

run "restrict_regions_with_attachment_targets" {
  command = apply

  variables {
    restrict_regions_attachment_targets = {
      policy_staging = "ou-policy1-12345678"
      sandbox        = "ou-sandbox-12345678"
      non_production = "ou-nonprod1-12345678"
      production     = "ou-prod123-12345678"
    }
  }

  assert {
    condition     = length(aws_organizations_policy_attachment.restrict_regions) == length(var.restrict_regions_attachment_targets)
    error_message = "Each restrict-regions target must create one corresponding attachment resource."
  }

  assert {
    condition = alltrue([
      for label, attachment in aws_organizations_policy_attachment.restrict_regions :
      attachment.policy_id == aws_organizations_policy.restrict_regions.id &&
      attachment.target_id == var.restrict_regions_attachment_targets[label]
    ])
    error_message = "Every restrict-regions attachment must reference the restrict-regions policy and its supplied target ID."
  }

  assert {
    condition     = toset([for attachment in aws_organizations_policy_attachment.restrict_regions : attachment.target_id]) == toset(values(var.restrict_regions_attachment_targets))
    error_message = "All supplied restrict-regions target IDs must propagate to the expected attachments."
  }

  assert {
    condition     = length(aws_organizations_policy_attachment.protect_account_membership) == 0
    error_message = "Restrict-regions attachments must not create protect-account-membership attachments."
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

run "invalid_restrict_regions_attachment_target_fails" {
  command = plan

  variables {
    restrict_regions_attachment_targets = {
      invalid = "not-an-organizations-target"
    }
  }

  expect_failures = [var.restrict_regions_attachment_targets]
}
