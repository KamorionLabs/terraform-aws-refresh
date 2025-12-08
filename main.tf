# terraform-aws-refresh
# Cross-account database refresh orchestrator using AWS Step Functions
#
# This module deploys Step Functions for orchestrating database refresh
# operations across multiple AWS accounts (source production -> destination non-prod)

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Step Functions - Database Module
# -----------------------------------------------------------------------------
module "step_functions_db" {
  source = "./modules/step-functions/db"

  prefix                     = var.prefix
  environment               = var.environment
  tags                      = var.tags

  # Cross-account configuration
  source_account_id         = var.source_account_id
  destination_account_ids   = var.destination_account_ids
  orchestrator_role_arn     = module.iam.orchestrator_role_arn
}

# -----------------------------------------------------------------------------
# Step Functions - EFS Module (TODO)
# -----------------------------------------------------------------------------
# module "step_functions_efs" {
#   source = "./modules/step-functions/efs"
#   ...
# }

# -----------------------------------------------------------------------------
# Step Functions - EKS Module (TODO)
# -----------------------------------------------------------------------------
# module "step_functions_eks" {
#   source = "./modules/step-functions/eks"
#   ...
# }

# -----------------------------------------------------------------------------
# Step Functions - Utils Module (TODO)
# -----------------------------------------------------------------------------
# module "step_functions_utils" {
#   source = "./modules/step-functions/utils"
#   ...
# }

# -----------------------------------------------------------------------------
# IAM Roles for Cross-Account Access
# -----------------------------------------------------------------------------
module "iam" {
  source = "./modules/iam"

  prefix                    = var.prefix
  environment              = var.environment
  tags                     = var.tags

  source_account_id        = var.source_account_id
  destination_account_ids  = var.destination_account_ids

  # Optional: AWS Organization
  use_aws_organization     = var.use_aws_organization
  aws_organization_id      = var.aws_organization_id
}

# -----------------------------------------------------------------------------
# Orchestrator (TODO)
# -----------------------------------------------------------------------------
# module "orchestrator" {
#   source = "./modules/orchestrator"
#   ...
# }
