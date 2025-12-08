output "step_function_arns" {
  description = "Map of Step Function names to ARNs"
  value = {
    for k, v in aws_sfn_state_machine.orchestrator : k => v.arn
  }
}

output "step_function_names" {
  description = "Map of Step Function keys to actual names"
  value = {
    for k, v in aws_sfn_state_machine.orchestrator : k => v.name
  }
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = var.enable_logging ? aws_cloudwatch_log_group.sfn[0].arn : null
}

output "orchestrator_arn" {
  description = "ARN of the main orchestrator Step Function"
  value       = aws_sfn_state_machine.orchestrator["refresh_orchestrator"].arn
}

output "orchestrator_name" {
  description = "Name of the main orchestrator Step Function"
  value       = aws_sfn_state_machine.orchestrator["refresh_orchestrator"].name
}
