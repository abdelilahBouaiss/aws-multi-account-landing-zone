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
