mock_provider "aws" {
  mock_resource "aws_organizations_organization" {
    defaults = {
      arn = "arn:aws:organizations::000000000000:organization/o-example"
      id  = "o-example"
      roots = [{
        arn          = "arn:aws:organizations::000000000000:root/o-example/r-example"
        id           = "r-example"
        name         = "Root"
        policy_types = []
      }]
    }
  }

  mock_resource "aws_organizations_organizational_unit" {
    defaults = {
      arn = "arn:aws:organizations::000000000000:ou/o-example/ou-abcde123-12345678"
      id  = "ou-abcde123-12345678"
    }
  }
}

run "organization_hierarchy" {
  command = apply

  variables {
    tags = {
      Project     = "organization-test"
      Environment = "test"
      ManagedBy   = "Terraform"
      Owner       = "platform"
      CostCenter  = "test"
    }
  }

  assert {
    condition     = aws_organizations_organization.this.feature_set == "ALL"
    error_message = "The organization must enable all AWS Organizations features."
  }

  assert {
    condition = toset([
      for organizational_unit in aws_organizations_organizational_unit.top_level : organizational_unit.name
    ]) == toset(["Security", "Infrastructure", "Workloads", "Sandbox", "Policy-Staging"])
    error_message = "The approved top-level OU names must be represented."
  }

  assert {
    condition     = toset(keys(output.top_level_ou_ids)) == toset(["security", "infrastructure", "workloads", "sandbox", "policy_staging"])
    error_message = "The top-level OU output must expose exactly the approved OU keys."
  }

  assert {
    condition = alltrue([
      for organizational_unit in aws_organizations_organizational_unit.top_level :
      organizational_unit.parent_id == aws_organizations_organization.this.roots[0].id
    ])
    error_message = "Every top-level OU must use the organization root as its parent."
  }

  assert {
    condition     = alltrue([for organizational_unit in aws_organizations_organizational_unit.top_level : organizational_unit.tags == var.tags])
    error_message = "Every top-level OU must receive the supplied test tags."
  }

  assert {
    condition = toset([
      for organizational_unit in aws_organizations_organizational_unit.workload : organizational_unit.name
    ]) == toset(["NonProduction", "Production"])
    error_message = "The approved nested workload OU names must be represented."
  }

  assert {
    condition     = toset(keys(output.workload_ou_ids)) == toset(["non_production", "production"])
    error_message = "The workload OU output must expose exactly the approved OU keys."
  }

  assert {
    condition = alltrue([
      for organizational_unit in aws_organizations_organizational_unit.workload :
      organizational_unit.parent_id == aws_organizations_organizational_unit.top_level["workloads"].id
    ])
    error_message = "NonProduction and Production must use Workloads as their parent."
  }

  assert {
    condition     = alltrue([for organizational_unit in aws_organizations_organizational_unit.workload : organizational_unit.tags == var.tags])
    error_message = "Every nested workload OU must receive the supplied test tags."
  }

  assert {
    condition     = output.organization_id == aws_organizations_organization.this.id && output.organization_arn == aws_organizations_organization.this.arn && output.root_id == aws_organizations_organization.this.roots[0].id
    error_message = "Outputs must expose the organization ID, ARN, and root ID."
  }

  assert {
    condition     = output.top_level_ou_ids["workloads"] == aws_organizations_organizational_unit.top_level["workloads"].id && output.workload_ou_ids["production"] == aws_organizations_organizational_unit.workload["production"].id
    error_message = "Outputs must expose the top-level and nested workload hierarchy."
  }
}
