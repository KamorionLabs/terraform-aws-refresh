# -----------------------------------------------------------------------------
# General Variables
# -----------------------------------------------------------------------------

variable "prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "refresh"
}

variable "environment" {
  description = "Environment name (e.g., prod, staging, dev)"
  type        = string
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

variable "shared_services_account_id" {
  description = "AWS Account ID where the orchestrator runs (if different from current)"
  type        = string
  default     = null
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

# -----------------------------------------------------------------------------
# Database Configuration
# -----------------------------------------------------------------------------

variable "default_kms_key_id" {
  description = "Default KMS key ID for encrypted resources"
  type        = string
  default     = null
}

variable "default_vpc_security_group_ids" {
  description = "Default VPC security group IDs for RDS clusters"
  type        = list(string)
  default     = []
}

variable "default_db_subnet_group_name" {
  description = "Default DB subnet group name for RDS clusters"
  type        = string
  default     = null
}
