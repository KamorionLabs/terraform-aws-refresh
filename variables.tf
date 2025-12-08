# -----------------------------------------------------------------------------
# General Variables
# -----------------------------------------------------------------------------

variable "prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "refresh"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Cross-Account Configuration
# -----------------------------------------------------------------------------

variable "source_account_id" {
  description = "AWS Account ID of the source (production) account"
  type        = string
}

variable "destination_account_ids" {
  description = "List of AWS Account IDs for destination accounts (non-prod)"
  type        = list(string)
}

# -----------------------------------------------------------------------------
# AWS Organization (Optional)
# -----------------------------------------------------------------------------

variable "use_aws_organization" {
  description = "Whether to use AWS Organization for trust policies"
  type        = bool
  default     = false
}

variable "aws_organization_id" {
  description = "AWS Organization ID (required if use_aws_organization is true)"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Step Functions Configuration
# -----------------------------------------------------------------------------

variable "enable_step_functions_logging" {
  description = "Enable CloudWatch logging for Step Functions"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing for Step Functions"
  type        = bool
  default     = false
}
