# -----------------------------------------------------------------------------
# Variables - Lambda Code Module
# -----------------------------------------------------------------------------

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "refresh"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "cross_account_role_arns" {
  description = "List of cross-account IAM role ARNs that need access to Lambda code (source and destination account roles)"
  type        = list(string)
  default     = []
}
