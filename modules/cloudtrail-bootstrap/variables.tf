variable "security_tooling_account_id" {
  type        = string
  description = "12-digit member-account ID for the Security Tooling CloudTrail delegated administrator."
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]{12}$", var.security_tooling_account_id))
    error_message = "security_tooling_account_id must contain exactly 12 digits."
  }
}
