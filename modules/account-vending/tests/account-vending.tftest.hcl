mock_provider "aws" {
  mock_resource "aws_organizations_account" {
    defaults = {
      arn = "arn:aws:organizations::000000000000:account/o-example/123456789012"
      id  = "123456789012"
    }
  }
}

variables {
  common_tags = {
    Project    = "landing-zone"
    ManagedBy  = "Terraform"
    Owner      = "platform"
    CostCenter = "shared"
  }

  accounts = {
    security_tooling = {
      name      = "security-tooling"
      email     = "security-tooling@example.test"
      parent_id = "ou-secure12-12345678"
      tags      = {}
    }
    log_archive = {
      name      = "log-archive"
      email     = "log-archive@example.test"
      parent_id = "ou-secure12-12345678"
      tags      = {}
    }
    shared_services = {
      name      = "shared-services"
      email     = "shared-services@example.test"
      parent_id = "ou-infra12-12345678"
      tags      = {}
    }
    development = {
      name      = "development"
      email     = "development@example.test"
      parent_id = "ou-nonprod1-12345678"
      tags = {
        Environment = "development"
      }
    }
    staging = {
      name      = "staging"
      email     = "staging@example.test"
      parent_id = "ou-nonprod1-12345678"
      tags = {
        Environment = "staging"
      }
    }
    production = {
      name      = "production"
      email     = "production@example.test"
      parent_id = "ou-prod123-12345678"
      tags = {
        Environment = "production"
        Owner       = "production-platform"
      }
    }
    sandbox = {
      name      = "sandbox"
      email     = "sandbox@example.test"
      parent_id = "ou-sandbox-12345678"
      tags      = {}
    }
    policy_test = {
      name      = "policy-test"
      email     = "policy-test@example.test"
      parent_id = "ou-policy1-12345678"
      tags      = {}
    }
  }
}

run "approved_accounts" {
  command = apply

  assert {
    condition     = length(aws_organizations_account.this) == 8
    error_message = "Exactly eight approved member-account resources must be created."
  }

  assert {
    condition     = toset(keys(aws_organizations_account.this)) == toset(keys(var.accounts))
    error_message = "The account resources must use the approved logical account keys."
  }

  assert {
    condition = alltrue([
      for key, account in var.accounts :
      aws_organizations_account.this[key].name == account.name &&
      aws_organizations_account.this[key].email == account.email &&
      aws_organizations_account.this[key].parent_id == account.parent_id
    ])
    error_message = "Each account resource must use its supplied name, email, and parent_id."
  }

  assert {
    condition     = alltrue([for account in aws_organizations_account.this : account.close_on_deletion == false])
    error_message = "All member accounts must set close_on_deletion to false."
  }

  assert {
    condition = alltrue([
      for key, account in var.accounts :
      aws_organizations_account.this[key].tags == merge(var.common_tags, account.tags)
    ])
    error_message = "Common tags must be merged first and account-specific tags must override them."
  }

  assert {
    condition     = toset(keys(output.account_ids)) == toset(["security_tooling", "log_archive", "shared_services", "development", "staging", "production", "sandbox", "policy_test"])
    error_message = "The account_ids output must expose exactly the approved logical account keys."
  }

  assert {
    condition     = toset(keys(output.account_arns)) == toset(["security_tooling", "log_archive", "shared_services", "development", "staging", "production", "sandbox", "policy_test"])
    error_message = "The account_arns output must expose exactly the approved logical account keys."
  }
}

run "duplicate_emails_fail" {
  command = plan

  variables {
    accounts = {
      security_tooling = {
        name      = "security-tooling"
        email     = "security-tooling@example.test"
        parent_id = "ou-secure12-12345678"
      }
      log_archive = {
        name      = "log-archive"
        email     = "log-archive@example.test"
        parent_id = "ou-secure12-12345678"
      }
      shared_services = {
        name      = "shared-services"
        email     = "shared-services@example.test"
        parent_id = "ou-infra12-12345678"
      }
      development = {
        name      = "development"
        email     = "development@example.test"
        parent_id = "ou-nonprod1-12345678"
      }
      staging = {
        name      = "staging"
        email     = "development@example.test"
        parent_id = "ou-nonprod1-12345678"
      }
      production = {
        name      = "production"
        email     = "production@example.test"
        parent_id = "ou-prod123-12345678"
      }
      sandbox = {
        name      = "sandbox"
        email     = "sandbox@example.test"
        parent_id = "ou-sandbox-12345678"
      }
      policy_test = {
        name      = "policy-test"
        email     = "policy-test@example.test"
        parent_id = "ou-policy1-12345678"
      }
    }
  }

  expect_failures = [var.accounts]
}

run "missing_account_key_fails" {
  command = plan

  variables {
    accounts = {
      security_tooling = {
        name      = "security-tooling"
        email     = "security-tooling@example.test"
        parent_id = "ou-secure12-12345678"
      }
      log_archive = {
        name      = "log-archive"
        email     = "log-archive@example.test"
        parent_id = "ou-secure12-12345678"
      }
      shared_services = {
        name      = "shared-services"
        email     = "shared-services@example.test"
        parent_id = "ou-infra12-12345678"
      }
      development = {
        name      = "development"
        email     = "development@example.test"
        parent_id = "ou-nonprod1-12345678"
      }
      staging = {
        name      = "staging"
        email     = "staging@example.test"
        parent_id = "ou-nonprod1-12345678"
      }
      production = {
        name      = "production"
        email     = "production@example.test"
        parent_id = "ou-prod123-12345678"
      }
      sandbox = {
        name      = "sandbox"
        email     = "sandbox@example.test"
        parent_id = "ou-sandbox-12345678"
      }
    }
  }

  expect_failures = [var.accounts]
}

run "extra_account_key_fails" {
  command = plan

  variables {
    accounts = {
      security_tooling = {
        name      = "security-tooling"
        email     = "security-tooling@example.test"
        parent_id = "ou-secure12-12345678"
      }
      log_archive = {
        name      = "log-archive"
        email     = "log-archive@example.test"
        parent_id = "ou-secure12-12345678"
      }
      shared_services = {
        name      = "shared-services"
        email     = "shared-services@example.test"
        parent_id = "ou-infra12-12345678"
      }
      development = {
        name      = "development"
        email     = "development@example.test"
        parent_id = "ou-nonprod1-12345678"
      }
      staging = {
        name      = "staging"
        email     = "staging@example.test"
        parent_id = "ou-nonprod1-12345678"
      }
      production = {
        name      = "production"
        email     = "production@example.test"
        parent_id = "ou-prod123-12345678"
      }
      sandbox = {
        name      = "sandbox"
        email     = "sandbox@example.test"
        parent_id = "ou-sandbox-12345678"
      }
      policy_test = {
        name      = "policy-test"
        email     = "policy-test@example.test"
        parent_id = "ou-policy1-12345678"
      }
      extra = {
        name      = "extra"
        email     = "extra@example.test"
        parent_id = "ou-extra12-12345678"
      }
    }
  }

  expect_failures = [var.accounts]
}

run "invalid_email_fails" {
  command = plan

  variables {
    accounts = {
      security_tooling = {
        name      = "security-tooling"
        email     = "not-an-email"
        parent_id = "ou-secure12-12345678"
      }
      log_archive = {
        name      = "log-archive"
        email     = "log-archive@example.test"
        parent_id = "ou-secure12-12345678"
      }
      shared_services = {
        name      = "shared-services"
        email     = "shared-services@example.test"
        parent_id = "ou-infra12-12345678"
      }
      development = {
        name      = "development"
        email     = "development@example.test"
        parent_id = "ou-nonprod1-12345678"
      }
      staging = {
        name      = "staging"
        email     = "staging@example.test"
        parent_id = "ou-nonprod1-12345678"
      }
      production = {
        name      = "production"
        email     = "production@example.test"
        parent_id = "ou-prod123-12345678"
      }
      sandbox = {
        name      = "sandbox"
        email     = "sandbox@example.test"
        parent_id = "ou-sandbox-12345678"
      }
      policy_test = {
        name      = "policy-test"
        email     = "policy-test@example.test"
        parent_id = "ou-policy1-12345678"
      }
    }
  }

  expect_failures = [var.accounts]
}

run "invalid_parent_id_fails" {
  command = plan

  variables {
    accounts = {
      security_tooling = {
        name      = "security-tooling"
        email     = "security-tooling@example.test"
        parent_id = "root-not-an-ou"
      }
      log_archive = {
        name      = "log-archive"
        email     = "log-archive@example.test"
        parent_id = "ou-secure12-12345678"
      }
      shared_services = {
        name      = "shared-services"
        email     = "shared-services@example.test"
        parent_id = "ou-infra12-12345678"
      }
      development = {
        name      = "development"
        email     = "development@example.test"
        parent_id = "ou-nonprod1-12345678"
      }
      staging = {
        name      = "staging"
        email     = "staging@example.test"
        parent_id = "ou-nonprod1-12345678"
      }
      production = {
        name      = "production"
        email     = "production@example.test"
        parent_id = "ou-prod123-12345678"
      }
      sandbox = {
        name      = "sandbox"
        email     = "sandbox@example.test"
        parent_id = "ou-sandbox-12345678"
      }
      policy_test = {
        name      = "policy-test"
        email     = "policy-test@example.test"
        parent_id = "ou-policy1-12345678"
      }
    }
  }

  expect_failures = [var.accounts]
}
