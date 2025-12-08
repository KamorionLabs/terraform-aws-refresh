# -----------------------------------------------------------------------------
# IAM Outputs
# -----------------------------------------------------------------------------

output "orchestrator_role_arn" {
  description = "ARN of the orchestrator IAM role"
  value       = module.iam.orchestrator_role_arn
}

output "source_role_arn" {
  description = "ARN of the source account IAM role (to be created in source account)"
  value       = module.iam.source_role_arn
}

output "destination_role_arn" {
  description = "ARN of the destination account IAM role (to be created in destination accounts)"
  value       = module.iam.destination_role_arn
}

# -----------------------------------------------------------------------------
# Step Functions - Database Outputs
# -----------------------------------------------------------------------------

output "step_functions_db" {
  description = "Map of database Step Functions ARNs"
  value       = module.step_functions_db.step_function_arns
}

# -----------------------------------------------------------------------------
# Step Functions - All Modules (TODO)
# -----------------------------------------------------------------------------

# output "step_functions_efs" {
#   description = "Map of EFS Step Functions ARNs"
#   value       = module.step_functions_efs.step_function_arns
# }

# output "step_functions_eks" {
#   description = "Map of EKS Step Functions ARNs"
#   value       = module.step_functions_eks.step_function_arns
# }

# output "orchestrator_arn" {
#   description = "ARN of the main orchestrator Step Function"
#   value       = module.orchestrator.orchestrator_arn
# }
