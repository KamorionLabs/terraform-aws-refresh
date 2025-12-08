# -----------------------------------------------------------------------------
# EKS Step Functions Module
# Cross-account Step Functions for EKS operations
# -----------------------------------------------------------------------------

locals {
  step_functions = {
    # Storage Management
    manage_storage = "manage_storage.asl.json"

    # Scaling
    scale_nodegroup_asg = "scale_nodegroup_asg.asl.json"
  }
}

# -----------------------------------------------------------------------------
# Step Functions Resources
# -----------------------------------------------------------------------------

resource "aws_sfn_state_machine" "eks" {
  for_each = local.step_functions

  name     = "${var.prefix}-EKS-${replace(title(replace(each.key, "_", " ")), " ", "")}"
  role_arn = var.orchestrator_role_arn

  definition = file("${path.module}/${each.value}")

  logging_configuration {
    log_destination        = var.enable_logging ? "${aws_cloudwatch_log_group.sfn[0].arn}:*" : null
    include_execution_data = var.enable_logging
    level                  = var.enable_logging ? "ALL" : "OFF"
  }

  tracing_configuration {
    enabled = var.enable_xray_tracing
  }

  tags = merge(var.tags, {
    Module = "eks"
    Name   = "${var.prefix}-EKS-${each.key}"
  })
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "sfn" {
  count = var.enable_logging ? 1 : 0

  name              = "/aws/stepfunctions/${var.prefix}-eks"
  retention_in_days = var.log_retention_days

  tags = var.tags
}
