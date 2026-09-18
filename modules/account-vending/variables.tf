variable "accounts" {
  type = map(object({
    name      = string
    email     = string
    parent_id = string
    tags      = optional(map(string), {})
  }))
  description = "The approved member accounts keyed by stable logical account role. Callers must provide names, unique owner emails, OU parent IDs, and optional account-specific tags."
  nullable    = false

  validation {
    condition = toset(keys(var.accounts)) == toset([
      "security_tooling",
      "log_archive",
      "shared_services",
      "development",
      "staging",
      "production",
      "sandbox",
      "policy_test",
    ])
    error_message = "accounts must contain exactly the approved keys: security_tooling, log_archive, shared_services, development, staging, production, sandbox, and policy_test."
  }

  validation {
    condition = alltrue([
      for account in values(var.accounts) :
      trimspace(account.name) == account.name &&
      trimspace(account.name) != "" &&
      length(account.name) <= 50
    ])
    error_message = "Each account name must be non-empty, must not have leading or trailing whitespace, and must be no longer than 50 characters."
  }

  validation {
    condition = alltrue([
      for account in values(var.accounts) :
      length(account.email) >= 6 &&
      length(account.email) <= 64 &&
      trimspace(account.email) == account.email &&
      !can(regex("[^\\x00-\\x7F]", account.email))
    ])
    error_message = "Each account email must be 6-64 ASCII characters with no leading or trailing whitespace."
  }

  validation {
    condition = alltrue([
      for account in values(var.accounts) :
      try(
        length(regexall("@", account.email)) == 1 &&
        length(split("@", account.email)) == 2 &&
        split("@", account.email)[0] != "" &&
        !startswith(split("@", account.email)[0], ".") &&
        split("@", account.email)[1] != "" &&
        strcontains(split("@", account.email)[1], "."),
        false
      )
    ])
    error_message = "Each account email must contain exactly one @, a non-empty local part that does not begin with a dot, and a dotted domain."
  }

  validation {
    condition = alltrue([
      for account in values(var.accounts) :
      !can(regex("[[:space:]\"'()<>\\[\\]:;,\\\\|%&]", try(split("@", account.email)[0], "")))
    ])
    error_message = "The local part of each account email must exclude whitespace and AWS Organizations forbidden characters."
  }

  validation {
    condition = alltrue([
      for account in values(var.accounts) :
      try(
        can(regex("^[A-Za-z0-9.-]+$", split("@", account.email)[1])) &&
        !can(regex("^[.-]", split("@", account.email)[1])) &&
        !can(regex("[.-]$", split("@", account.email)[1])),
        false
      )
    ])
    error_message = "Each account email domain must contain only letters, numbers, hyphens, and dots, and must not begin or end with a hyphen or dot."
  }

  validation {
    condition     = length(toset([for account in values(var.accounts) : lower(account.email)])) == length(var.accounts)
    error_message = "Account emails must be unique within the supplied accounts map; AWS must validate global uniqueness."
  }

  validation {
    condition = alltrue([
      for account in values(var.accounts) :
      can(regex("^ou-[a-z0-9]{4,32}-[a-z0-9]{8,32}$", account.parent_id))
    ])
    error_message = "Each account parent_id must match an AWS Organizations OU ID shape; organization root IDs are not accepted."
  }

  validation {
    condition = alltrue(flatten([
      for account in values(var.accounts) : [
        for key, value in account.tags : trimspace(key) != "" && trimspace(value) != ""
      ]
    ]))
    error_message = "Account-specific tag keys and values must not be empty or whitespace-only."
  }
}

variable "common_tags" {
  type        = map(string)
  description = "Optional tags applied to every member account before account-specific tags are merged."
  default     = {}
  nullable    = false

  validation {
    condition = alltrue([
      for key, value in var.common_tags : trimspace(key) != "" && trimspace(value) != ""
    ])
    error_message = "Common tag keys and values must not be empty or whitespace-only."
  }
}
