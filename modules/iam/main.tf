# -----------------------------------------------------------------------------
# IAM Module for Cross-Account Refresh
# Creates IAM roles for orchestrator, source, and destination accounts
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  orchestrator_account_id = data.aws_caller_identity.current.account_id
}

# -----------------------------------------------------------------------------
# Orchestrator Role (deployed in shared services account)
# This role is assumed by Step Functions to orchestrate cross-account operations
# -----------------------------------------------------------------------------

resource "aws_iam_role" "orchestrator" {
  name = "${var.prefix}-orchestrator-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "orchestrator_assume_roles" {
  name = "${var.prefix}-assume-cross-account-roles"
  role = aws_iam_role.orchestrator.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = concat(
          [
            "arn:aws:iam::${var.source_account_id}:role/${var.prefix}-source-role"
          ],
          [
            for account_id in var.destination_account_ids :
            "arn:aws:iam::${account_id}:role/${var.prefix}-destination-role"
          ]
        )
      }
    ]
  })
}

resource "aws_iam_role_policy" "orchestrator_step_functions" {
  name = "${var.prefix}-step-functions"
  role = aws_iam_role.orchestrator.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution",
          "states:DescribeExecution",
          "states:StopExecution"
        ]
        Resource = "arn:aws:states:${data.aws_region.current.name}:${local.orchestrator_account_id}:stateMachine:${var.prefix}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution.sync",
          "states:StartExecution.sync:2"
        ]
        Resource = "arn:aws:states:${data.aws_region.current.name}:${local.orchestrator_account_id}:stateMachine:${var.prefix}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "events:PutTargets",
          "events:PutRule",
          "events:DescribeRule"
        ]
        Resource = "arn:aws:events:${data.aws_region.current.name}:${local.orchestrator_account_id}:rule/StepFunctionsGetEventsForStepFunctionsExecutionRule"
      }
    ]
  })
}

resource "aws_iam_role_policy" "orchestrator_logging" {
  name = "${var.prefix}-logging"
  role = aws_iam_role.orchestrator.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutLogEvents",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Source Role Policy Document (to be deployed in source account)
# This is output as a JSON document for reference
# -----------------------------------------------------------------------------

locals {
  source_role_trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.orchestrator_account_id}:role/${var.prefix}-orchestrator-role"
        }
        Action = "sts:AssumeRole"
        Condition = var.use_aws_organization ? {
          StringEquals = {
            "aws:PrincipalOrgID" = var.aws_organization_id
          }
        } : null
      }
    ]
  })

  source_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RDSReadOnly"
        Effect = "Allow"
        Action = [
          "rds:Describe*",
          "rds:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "RDSSnapshotSharing"
        Effect = "Allow"
        Action = [
          "rds:ModifyDBClusterSnapshotAttribute",
          "rds:CreateDBClusterSnapshot"
        ]
        Resource = "arn:aws:rds:*:${var.source_account_id}:cluster-snapshot:*"
      },
      {
        Sid    = "KMSGrant"
        Effect = "Allow"
        Action = [
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "kms:ViaService" = "rds.*.amazonaws.com"
          }
        }
      },
      {
        Sid    = "SecretsReadOnly"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:*:${var.source_account_id}:secret:*"
      },
      {
        Sid    = "EFSReadOnly"
        Effect = "Allow"
        Action = [
          "elasticfilesystem:Describe*"
        ]
        Resource = "*"
      },
      {
        Sid    = "EFSReplication"
        Effect = "Allow"
        Action = [
          "elasticfilesystem:CreateReplicationConfiguration",
          "elasticfilesystem:DeleteReplicationConfiguration"
        ]
        Resource = "arn:aws:elasticfilesystem:*:${var.source_account_id}:file-system/*"
      }
    ]
  })

  # Destination Role Policy
  destination_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RDSFullAccess"
        Effect = "Allow"
        Action = [
          "rds:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "SecretsManagerFullAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "EFSFullAccess"
        Effect = "Allow"
        Action = [
          "elasticfilesystem:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "EKSAccess"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      },
      {
        Sid    = "EKSRunJob"
        Effect = "Allow"
        Action = [
          "eks:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "LambdaInvoke"
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "lambda:GetFunction",
          "lambda:UpdateFunctionConfiguration"
        ]
        Resource = "*"
      },
      {
        Sid    = "SSMParameters"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:PutParameter"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject"
        ]
        Resource = "*"
      },
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      },
      {
        Sid    = "AutoScaling"
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:UpdateAutoScalingGroup",
          "autoscaling:SetDesiredCapacity"
        ]
        Resource = "*"
      },
      {
        Sid    = "Tagging"
        Effect = "Allow"
        Action = [
          "tag:TagResources",
          "tag:UntagResources"
        ]
        Resource = "*"
      }
    ]
  })
}
