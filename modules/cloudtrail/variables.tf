variable "trail_name" {
  type        = string
  description = "Name of the single AWS Organizations CloudTrail trail."
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

variable "s3_bucket_name" {
  type        = string
  description = "Name of the externally managed Log Archive S3 bucket for CloudTrail delivery."
  nullable    = false

  validation {
    condition = (
      length(var.s3_bucket_name) >= 3 &&
      length(var.s3_bucket_name) <= 63 &&
      trimspace(var.s3_bucket_name) == var.s3_bucket_name &&
      can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.s3_bucket_name)) &&
      !strcontains(var.s3_bucket_name, "..") &&
      !can(regex("^[0-9]+(\\.[0-9]+){3}$", var.s3_bucket_name))
    )
    error_message = "s3_bucket_name must be a practical 3-63 character S3 bucket name without boundary whitespace, adjacent periods, or IPv4 address form."
  }
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of the externally managed customer-managed KMS key used by the organization trail; alias ARNs are not accepted."
  nullable    = false

  validation {
    condition = (
      trimspace(var.kms_key_arn) == var.kms_key_arn &&
      can(regex("^arn:[a-z0-9-]+:kms:[a-z0-9-]+:[0-9]{12}:key/[A-Za-z0-9-]+$", var.kms_key_arn))
    )
    error_message = "kms_key_arn must be a KMS key ARN with a partition, Region, 12-digit account ID, and key/ resource; alias ARNs are not accepted."
  }
}

variable "home_region" {
  type        = string
  description = "Home Region for the organization trail; the approved v1 architecture fixes this to eu-west-1."
  default     = "eu-west-1"
  nullable    = false

  validation {
    condition     = var.home_region == "eu-west-1"
    error_message = "home_region must be eu-west-1 for the approved v1 architecture."
  }
}

variable "tags" {
  type        = map(string)
  description = "Optional semantic tags applied to the CloudTrail trail."
  default     = {}
  nullable    = false

  validation {
    condition = alltrue([
      for key, value in var.tags : trimspace(key) != "" && trimspace(value) != ""
    ])
    error_message = "Tag keys and values must not be empty or whitespace-only."
  }
}
