# -----------------------------------------------------------------------------
# Variables - Source Account Module
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

variable "orchestrator_role_arn" {
  description = "ARN of the orchestrator IAM role (from shared services account). Required if create_role is true."
  type        = string
  default     = null
}

variable "aws_organization_id" {
  description = "AWS Organization ID for additional trust policy condition (optional)"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# IAM Role Configuration
# -----------------------------------------------------------------------------

variable "create_role" {
  description = "Create IAM role for source account. Set to false to use existing_role_arn."
  type        = bool
  default     = true
}

variable "existing_role_arn" {
  description = "ARN of existing IAM role to use instead of creating one. Required if create_role is false."
  type        = string
  default     = null
}

variable "existing_role_name" {
  description = "Name of existing IAM role (for attaching policies). Required if create_role is false and attach_policies is true."
  type        = string
  default     = null
}

variable "attach_policies" {
  description = "Attach IAM policies to the role. Set to false if policies are managed externally."
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Feature Toggles
# -----------------------------------------------------------------------------

variable "enable_efs" {
  description = "Enable EFS-related permissions (for backup copy)"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Resource ARNs
# -----------------------------------------------------------------------------

variable "kms_key_arns" {
  description = "List of KMS key ARNs for snapshot encryption"
  type        = list(string)
  default     = ["*"]
}
