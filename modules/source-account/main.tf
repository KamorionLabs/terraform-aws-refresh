# -----------------------------------------------------------------------------
# Source Account Module
# Deploys IAM role in source (production) accounts for cross-account access
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.id

  # Use existing role or created role
  role_arn  = var.create_role ? aws_iam_role.source[0].arn : var.existing_role_arn
  role_name = var.create_role ? aws_iam_role.source[0].name : var.existing_role_name
  role_id   = var.create_role ? aws_iam_role.source[0].id : var.existing_role_name

  # Determine if we should attach policies
  should_attach_policies = var.attach_policies && local.role_id != null
}

# -----------------------------------------------------------------------------
# IAM Role - Assumable by Orchestrator (optional)
# -----------------------------------------------------------------------------

resource "aws_iam_role" "source" {
  count = var.create_role ? 1 : 0

  name = "${var.prefix}-source-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.orchestrator_role_arn
        }
        Action = "sts:AssumeRole"
        Condition = var.aws_organization_id != null ? {
          StringEquals = {
            "aws:PrincipalOrgID" = var.aws_organization_id
          }
        } : null
      }
    ]
  })

  tags = var.tags
}

# -----------------------------------------------------------------------------
# IAM Policy - RDS Read & Snapshot
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "rds_access" {
  count = local.should_attach_policies ? 1 : 0

  name = "${var.prefix}-rds-access"
  role = local.role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RDSRead"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBClusters",
          "rds:DescribeDBClusterSnapshots",
          "rds:DescribeDBInstances",
          "rds:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "RDSSnapshot"
        Effect = "Allow"
        Action = [
          "rds:CreateDBClusterSnapshot",
          "rds:CopyDBClusterSnapshot",
          "rds:AddTagsToResource"
        ]
        Resource = [
          "arn:aws:rds:*:${local.account_id}:cluster:*",
          "arn:aws:rds:*:${local.account_id}:cluster-snapshot:*"
        ]
      },
      {
        Sid    = "RDSSnapshotSharing"
        Effect = "Allow"
        Action = [
          "rds:ModifyDBClusterSnapshotAttribute"
        ]
        Resource = "arn:aws:rds:*:${local.account_id}:cluster-snapshot:*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM Policy - KMS for Snapshot Encryption
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "kms_access" {
  count = local.should_attach_policies ? 1 : 0

  name = "${var.prefix}-kms-access"
  role = local.role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:DescribeKey",
          "kms:CreateGrant",
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = var.kms_key_arns
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM Policy - EFS for Backup
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "efs_access" {
  count = local.should_attach_policies && var.enable_efs ? 1 : 0

  name = "${var.prefix}-efs-access"
  role = local.role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EFSRead"
        Effect = "Allow"
        Action = [
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeMountTargets",
          "elasticfilesystem:DescribeAccessPoints",
          "elasticfilesystem:DescribeBackupPolicy"
        ]
        Resource = "*"
      },
      {
        Sid    = "BackupRead"
        Effect = "Allow"
        Action = [
          "backup:DescribeBackupVault",
          "backup:ListRecoveryPointsByBackupVault",
          "backup:DescribeRecoveryPoint",
          "backup:GetRecoveryPointRestoreMetadata"
        ]
        Resource = "*"
      },
      {
        Sid    = "BackupCopy"
        Effect = "Allow"
        Action = [
          "backup:CopyIntoBackupVault",
          "backup:StartCopyJob",
          "backup:DescribeCopyJob"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM Policy - Secrets Manager (read-only)
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "secrets_access" {
  count = local.should_attach_policies ? 1 : 0

  name = "${var.prefix}-secrets-access"
  role = local.role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:*:${local.account_id}:secret:*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM Policy - Tagging
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "tagging_access" {
  count = local.should_attach_policies ? 1 : 0

  name = "${var.prefix}-tagging-access"
  role = local.role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Tagging"
        Effect = "Allow"
        Action = [
          "tag:GetResources"
        ]
        Resource = "*"
      }
    ]
  })
}
