output "orchestrator_role_arn" {
  description = "ARN of the orchestrator IAM role"
  value       = aws_iam_role.orchestrator.arn
}

output "orchestrator_role_name" {
  description = "Name of the orchestrator IAM role"
  value       = aws_iam_role.orchestrator.name
}

output "source_role_arn" {
  description = "Expected ARN of the source account role (to be created in source account)"
  value       = "arn:aws:iam::${var.source_account_id}:role/${var.prefix}-source-role"
}

output "destination_role_arn" {
  description = "Expected ARN pattern for destination account roles"
  value       = "${var.prefix}-destination-role"
}

output "source_role_trust_policy" {
  description = "Trust policy JSON for source account role"
  value       = local.source_role_trust_policy
}

output "source_role_policy" {
  description = "Policy JSON for source account role"
  value       = local.source_role_policy
}

output "destination_role_policy" {
  description = "Policy JSON for destination account roles"
  value       = local.destination_role_policy
}
