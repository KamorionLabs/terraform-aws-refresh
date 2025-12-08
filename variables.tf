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
# Cross-Account Role ARNs
# -----------------------------------------------------------------------------

variable "source_role_arns" {
  description = "List of IAM role ARNs in source accounts that the orchestrator can assume"
  type        = list(string)
}

variable "destination_role_arns" {
  description = "List of IAM role ARNs in destination accounts that the orchestrator can assume"
  type        = list(string)
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
