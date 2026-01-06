# -----------------------------------------------------------------------------
# Variables - Lambda Code Module
# -----------------------------------------------------------------------------

variable "prefix" {
  description = "Prefix for resource names (used for naming if bucket_name not provided)"
  type        = string
  default     = "refresh"
}

variable "bucket_name" {
  description = "Custom S3 bucket name. If not provided, uses prefix-lambda-code-account_id"
  type        = string
  default     = null
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
