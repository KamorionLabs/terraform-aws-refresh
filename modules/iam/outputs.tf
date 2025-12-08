output "orchestrator_role_arn" {
  description = "ARN of the orchestrator IAM role"
  value       = aws_iam_role.orchestrator.arn
}

output "orchestrator_role_name" {
  description = "Name of the orchestrator IAM role"
  value       = aws_iam_role.orchestrator.name
}
