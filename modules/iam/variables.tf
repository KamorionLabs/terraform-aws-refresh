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

variable "source_account_id" {
  description = "Source (production) AWS account ID"
  type        = string
}

variable "destination_account_ids" {
  description = "List of destination AWS account IDs"
  type        = list(string)
}

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
