variable "tags" {
  type        = map(string)
  description = "Common tags applied to organizational units where AWS Organizations supports tagging."
  default     = {}

  validation {
    condition = alltrue([
      for key, value in var.tags : trimspace(key) != "" && trimspace(value) != ""
    ])
    error_message = "Tag keys and values must not be empty or whitespace-only."
  }
}
