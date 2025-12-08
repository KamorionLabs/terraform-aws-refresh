variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "orchestrator_role_arn" {
  description = "ARN of the IAM role for Step Functions execution"
  type        = string
}

variable "source_account_id" {
  description = "Source (production) AWS account ID"
  type        = string
}

variable "destination_account_ids" {
  description = "List of destination AWS account IDs"
  type        = list(string)
}

variable "enable_logging" {
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
