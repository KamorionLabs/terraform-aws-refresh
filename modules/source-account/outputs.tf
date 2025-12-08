# -----------------------------------------------------------------------------
# Outputs - Source Account Module
# -----------------------------------------------------------------------------

output "role_arn" {
  description = "ARN of the source account IAM role"
  value       = local.role_arn
}

output "role_name" {
  description = "Name of the source account IAM role"
  value       = local.role_name
}

output "role_created" {
  description = "Whether the IAM role was created by this module"
  value       = var.create_role
}
