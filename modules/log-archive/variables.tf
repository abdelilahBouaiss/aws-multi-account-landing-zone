variable "bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name for centralized CloudTrail delivery."
  nullable    = false

  validation {
    condition = (
      length(var.bucket_name) >= 3 &&
      length(var.bucket_name) <= 63 &&
      trimspace(var.bucket_name) == var.bucket_name &&
      can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.bucket_name)) &&
      !strcontains(var.bucket_name, "..") &&
      !can(regex("^[0-9]+(\\.[0-9]+){3}$", var.bucket_name))
    )
    error_message = "bucket_name must be 3-63 characters, lowercase, S3-compatible, and must not contain boundary whitespace, adjacent periods, or an IPv4 address format."
  }
}

variable "organization_id" {
  type        = string
  description = "AWS Organizations ID used for the organization CloudTrail log path."
  nullable    = false

  validation {
    condition     = can(regex("^o-[a-z0-9]{10,32}$", var.organization_id))
    error_message = "organization_id must match the AWS Organizations ID shape o- followed by 10-32 lowercase letters or digits."
  }
}

variable "management_account_id" {
  type        = string
  description = "12-digit AWS Organizations management-account ID used to construct the organization trail ARN."
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]{12}$", var.management_account_id))
    error_message = "management_account_id must contain exactly 12 digits."
  }
}

variable "trail_name" {
  type        = string
  description = "CloudTrail organization trail name used to construct the authorized trail ARN."
  nullable    = false

  validation {
    condition = (
      length(var.trail_name) >= 3 &&
      length(var.trail_name) <= 128 &&
      trimspace(var.trail_name) == var.trail_name &&
      can(regex("^[A-Za-z0-9][A-Za-z0-9._-]{1,126}[A-Za-z0-9]$", var.trail_name))
    )
    error_message = "trail_name must be 3-128 characters, must not have boundary whitespace, and may contain letters, numbers, periods, underscores, and hyphens."
  }
}

variable "trail_home_region" {
  type        = string
  description = "Home Region for the organization trail; v1 is fixed to eu-west-1."
  default     = "eu-west-1"
  nullable    = false

  validation {
    condition     = var.trail_home_region == "eu-west-1"
    error_message = "trail_home_region must be eu-west-1 for the approved v1 architecture."
  }
}

variable "retention_days" {
  type        = number
  description = "Optional positive whole-number object expiration period. Null creates no expiration lifecycle rule."
  default     = null
  nullable    = true

  validation {
    condition = (
      var.retention_days == null ||
      try(var.retention_days > 0 && floor(var.retention_days) == var.retention_days, false)
    )
    error_message = "retention_days must be null or a positive whole number."
  }
}

variable "tags" {
  type        = map(string)
  description = "Optional semantic tags applied to the Log Archive S3 bucket and KMS key."
  default     = {}
  nullable    = false

  validation {
    condition = alltrue([
      for key, value in var.tags : trimspace(key) != "" && trimspace(value) != ""
    ])
    error_message = "Tag keys and values must not be empty or whitespace-only."
  }
}
