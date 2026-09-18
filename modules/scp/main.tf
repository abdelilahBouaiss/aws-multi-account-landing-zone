locals {
  # Keep the policy as a structured object so mocked native tests inspect the
  # actual document instead of a provider-mocked data-source placeholder.
  protect_account_membership_policy = {
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DenyAccountDepartureAndClosure"
      Effect = "Deny"
      Action = [
        "organizations:LeaveOrganization",
        "account:CloseAccount",
      ]
      Resource = "*"
    }]
  }

  restrict_regions_policy = {
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DenyOutsideApprovedRegion"
      Effect = "Deny"
      NotAction = [
        "cloudfront:*",
        "iam:*",
        "route53:*",
        "support:*",
        "organizations:*",
        "budgets:*",
        "sts:*",
      ]
      Resource = "*"
      Condition = {
        StringNotEquals = {
          "aws:RequestedRegion" = ["eu-west-1"]
        }
      }
    }]
  }

  protect_cloudtrail_policy = {
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DenyCloudTrailAuditWeakening"
      Effect = "Deny"
      Action = [
        "cloudtrail:StopLogging",
        "cloudtrail:DeleteTrail",
        "cloudtrail:UpdateTrail",
        "cloudtrail:PutEventSelectors",
      ]
      Resource = "*"
    }]
  }

  protect_security_services_policy = {
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DenySecurityServiceWeakening"
      Effect = "Deny"
      Action = [
        "guardduty:DeleteDetector",
        "guardduty:UpdateDetector",
        "securityhub:DisableSecurityHub",
        "securityhub:BatchDisableStandards",
        "securityhub:BatchUpdateStandardsControlAssociations",
        "securityhub:UpdateStandardsControl",
      ]
      Resource = "*"
    }]
  }
}

resource "aws_organizations_policy" "protect_account_membership" {
  name        = "protect-account-membership"
  description = "Prevent member accounts from leaving the organization or closing themselves."
  content     = jsonencode(local.protect_account_membership_policy)
  type        = "SERVICE_CONTROL_POLICY"
}

resource "aws_organizations_policy" "restrict_regions" {
  name        = "restrict-regions"
  description = "Restrict regional API activity to eu-west-1 while preserving approved global services."
  content     = jsonencode(local.restrict_regions_policy)
  type        = "SERVICE_CONTROL_POLICY"
}

resource "aws_organizations_policy" "protect_cloudtrail" {
  name        = "protect-cloudtrail"
  description = "Prevent governed accounts from weakening CloudTrail audit logging."
  content     = jsonencode(local.protect_cloudtrail_policy)
  type        = "SERVICE_CONTROL_POLICY"
}

resource "aws_organizations_policy" "protect_security_services" {
  name        = "protect-security-services"
  description = "Prevent governed accounts from weakening GuardDuty and Security Hub controls."
  content     = jsonencode(local.protect_security_services_policy)
  type        = "SERVICE_CONTROL_POLICY"
}

resource "aws_organizations_policy_attachment" "protect_account_membership" {
  for_each = var.attachment_targets

  policy_id = aws_organizations_policy.protect_account_membership.id
  target_id = each.value
}

resource "aws_organizations_policy_attachment" "restrict_regions" {
  for_each = var.restrict_regions_attachment_targets

  policy_id = aws_organizations_policy.restrict_regions.id
  target_id = each.value
}

resource "aws_organizations_policy_attachment" "protect_cloudtrail" {
  for_each = var.protect_cloudtrail_attachment_targets

  policy_id = aws_organizations_policy.protect_cloudtrail.id
  target_id = each.value
}

resource "aws_organizations_policy_attachment" "protect_security_services" {
  for_each = var.protect_security_services_attachment_targets

  policy_id = aws_organizations_policy.protect_security_services.id
  target_id = each.value
}
