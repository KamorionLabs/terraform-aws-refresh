# -----------------------------------------------------------------------------
# IAM Outputs
# -----------------------------------------------------------------------------

output "orchestrator_role_arn" {
  description = "ARN of the orchestrator IAM role"
  value       = module.iam.orchestrator_role_arn
}

output "orchestrator_role_name" {
  description = "Name of the orchestrator IAM role"
  value       = module.iam.orchestrator_role_name
}

# -----------------------------------------------------------------------------
# Step Functions - Database Outputs
# -----------------------------------------------------------------------------

output "step_functions_db" {
  description = "Map of database Step Functions ARNs"
  value       = module.step_functions_db.step_function_arns
}

# -----------------------------------------------------------------------------
# Step Functions - EFS Outputs
# -----------------------------------------------------------------------------

output "step_functions_efs" {
  description = "Map of EFS Step Functions ARNs"
  value       = module.step_functions_efs.step_function_arns
}

# -----------------------------------------------------------------------------
# Step Functions - EKS Outputs
# -----------------------------------------------------------------------------

output "step_functions_eks" {
  description = "Map of EKS Step Functions ARNs"
  value       = module.step_functions_eks.step_function_arns
}

# -----------------------------------------------------------------------------
# Step Functions - Utils Outputs
# -----------------------------------------------------------------------------

output "step_functions_utils" {
  description = "Map of Utils Step Functions ARNs"
  value       = module.step_functions_utils.step_function_arns
}

# -----------------------------------------------------------------------------
# Orchestrator Outputs
# -----------------------------------------------------------------------------

output "orchestrator_arn" {
  description = "ARN of the main orchestrator Step Function"
  value       = module.orchestrator.orchestrator_arn
}

output "orchestrator_name" {
  description = "Name of the main orchestrator Step Function"
  value       = module.orchestrator.orchestrator_name
}

# -----------------------------------------------------------------------------
# All Step Functions (consolidated)
# -----------------------------------------------------------------------------

output "all_step_function_arns" {
  description = "Consolidated map of all Step Function ARNs by module"
  value = {
    db           = module.step_functions_db.step_function_arns
    efs          = module.step_functions_efs.step_function_arns
    eks          = module.step_functions_eks.step_function_arns
    utils        = module.step_functions_utils.step_function_arns
    orchestrator = module.orchestrator.step_function_arns
  }
}
