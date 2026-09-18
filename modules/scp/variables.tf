variable "attachment_targets" {
  type        = map(string)
  description = "Optional map of stable attachment labels to AWS Organizations root, OU, or member-account IDs. An empty map creates no attachments."
  default     = {}
  nullable    = false

  validation {
    condition = alltrue([
      for label in keys(var.attachment_targets) : trimspace(label) != ""
    ])
    error_message = "Attachment target labels must not be empty or whitespace-only."
  }

  validation {
    condition = alltrue([
      for target_id in values(var.attachment_targets) :
      can(regex("^(r-[a-z0-9]{4,32}|ou-[a-z0-9]{4,32}-[a-z0-9]{8,32}|[0-9]{12})$", target_id))
    ])
    error_message = "Each attachment target must be an AWS Organizations root ID, OU ID, or 12-digit member-account ID."
  }
}

variable "restrict_regions_attachment_targets" {
  type        = map(string)
  description = "Optional map of stable attachment labels to AWS Organizations root, OU, or member-account IDs for restrict-regions. An empty map creates no attachments."
  default     = {}
  nullable    = false

  validation {
    condition = alltrue([
      for label in keys(var.restrict_regions_attachment_targets) : trimspace(label) != ""
    ])
    error_message = "Restrict-regions attachment target labels must not be empty or whitespace-only."
  }

  validation {
    condition = alltrue([
      for target_id in values(var.restrict_regions_attachment_targets) :
      can(regex("^(r-[a-z0-9]{4,32}|ou-[a-z0-9]{4,32}-[a-z0-9]{8,32}|[0-9]{12})$", target_id))
    ])
    error_message = "Each restrict-regions attachment target must be an AWS Organizations root ID, OU ID, or 12-digit member-account ID."
  }
}

variable "protect_cloudtrail_attachment_targets" {
  type        = map(string)
  description = "Optional map of stable attachment labels to AWS Organizations root, OU, or member-account IDs for protect-cloudtrail. An empty map creates no attachments."
  default     = {}
  nullable    = false

  validation {
    condition = alltrue([
      for label in keys(var.protect_cloudtrail_attachment_targets) : trimspace(label) != ""
    ])
    error_message = "Protect-CloudTrail attachment target labels must not be empty or whitespace-only."
  }

  validation {
    condition = alltrue([
      for target_id in values(var.protect_cloudtrail_attachment_targets) :
      can(regex("^(r-[a-z0-9]{4,32}|ou-[a-z0-9]{4,32}-[a-z0-9]{8,32}|[0-9]{12})$", target_id))
    ])
    error_message = "Each protect-CloudTrail attachment target must be an AWS Organizations root ID, OU ID, or 12-digit member-account ID."
  }
}

variable "protect_security_services_attachment_targets" {
  type        = map(string)
  description = "Optional map of stable attachment labels to AWS Organizations root, OU, or member-account IDs for protect-security-services. An empty map creates no attachments."
  default     = {}
  nullable    = false

  validation {
    condition = alltrue([
      for label in keys(var.protect_security_services_attachment_targets) : trimspace(label) != ""
    ])
    error_message = "Protect-security-services attachment target labels must not be empty or whitespace-only."
  }

  validation {
    condition = alltrue([
      for target_id in values(var.protect_security_services_attachment_targets) :
      can(regex("^(r-[a-z0-9]{4,32}|ou-[a-z0-9]{4,32}-[a-z0-9]{8,32}|[0-9]{12})$", target_id))
    ])
    error_message = "Each protect-security-services attachment target must be an AWS Organizations root ID, OU ID, or 12-digit member-account ID."
  }
}

variable "restrict_member_root_user_attachment_targets" {
  type        = map(string)
  description = "Optional map of stable attachment labels to AWS Organizations root, OU, or member-account IDs for restrict-member-root-user. An empty map creates no attachments."
  default     = {}
  nullable    = false

  validation {
    condition = alltrue([
      for label in keys(var.restrict_member_root_user_attachment_targets) : trimspace(label) != ""
    ])
    error_message = "Restrict-member-root-user attachment target labels must not be empty or whitespace-only."
  }

  validation {
    condition = alltrue([
      for target_id in values(var.restrict_member_root_user_attachment_targets) :
      can(regex("^(r-[a-z0-9]{4,32}|ou-[a-z0-9]{4,32}-[a-z0-9]{8,32}|[0-9]{12})$", target_id))
    ])
    error_message = "Each restrict-member-root-user attachment target must be an AWS Organizations root ID, OU ID, or 12-digit member-account ID."
  }
}
