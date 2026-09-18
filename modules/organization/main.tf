locals {
  top_level_ous = {
    security       = "Security"
    infrastructure = "Infrastructure"
    workloads      = "Workloads"
    sandbox        = "Sandbox"
    policy_staging = "Policy-Staging"
  }

  workload_ous = {
    non_production = "NonProduction"
    production     = "Production"
  }
}

resource "aws_organizations_organization" "this" {
  feature_set = "ALL"
}

resource "aws_organizations_organizational_unit" "top_level" {
  for_each = local.top_level_ous

  name      = each.value
  parent_id = aws_organizations_organization.this.roots[0].id
  tags      = var.tags
}

resource "aws_organizations_organizational_unit" "workload" {
  for_each = local.workload_ous

  name      = each.value
  parent_id = aws_organizations_organizational_unit.top_level["workloads"].id
  tags      = var.tags
}
