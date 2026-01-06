# -----------------------------------------------------------------------------
# Destination Account Module
# Deploys IAM role and Lambda helpers in destination (non-prod) accounts
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.id

  # Use existing role or created role
  role_arn  = var.create_role ? aws_iam_role.destination[0].arn : var.existing_role_arn
  role_name = var.create_role ? aws_iam_role.destination[0].name : var.existing_role_name
  role_id   = var.create_role ? aws_iam_role.destination[0].id : var.existing_role_name

  # Determine if we should attach policies
  # Use variables known at plan time to avoid "count depends on resource attributes" error
  should_attach_policies = var.attach_policies && (var.create_role || var.existing_role_name != null)
}

# -----------------------------------------------------------------------------
# IAM Role - Assumable by Orchestrator (optional)
# -----------------------------------------------------------------------------

resource "aws_iam_role" "destination" {
  count = var.create_role ? 1 : 0

  name = "${var.prefix}-destination-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      merge(
        {
          Effect = "Allow"
          Principal = {
            AWS = var.orchestrator_role_arn
          }
          Action = "sts:AssumeRole"
        },
        var.aws_organization_id != null ? {
          Condition = {
            StringEquals = {
              "aws:PrincipalOrgID" = var.aws_organization_id
            }
          }
        } : {}
      )
    ]
  })

  tags = var.tags
}

# -----------------------------------------------------------------------------
# IAM Policy - RDS Full Access
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "rds_access" {
  count = local.should_attach_policies ? 1 : 0

  name = "${var.prefix}-rds-access"
  role = local.role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RDSFullAccess"
        Effect = "Allow"
        Action = [
          "rds:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM Policy - Secrets Manager
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "secrets_access" {
  count = local.should_attach_policies ? 1 : 0

  name = "${var.prefix}-secrets-access"
  role = local.role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerFullAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM Policy - EFS
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "efs_access" {
  count = local.should_attach_policies && var.enable_efs ? 1 : 0

  name = "${var.prefix}-efs-access"
  role = local.role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EFSFullAccess"
        Effect = "Allow"
        Action = [
          "elasticfilesystem:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:GetMetricData"
        ]
        Resource = "*"
      },
      {
        Sid    = "BackupAccess"
        Effect = "Allow"
        Action = [
          "backup:StartRestoreJob",
          "backup:DescribeRestoreJob",
          "backup:GetRecoveryPointRestoreMetadata",
          "backup:ListRecoveryPointsByResource"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM Policy - EKS
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "eks_access" {
  count = local.should_attach_policies && var.enable_eks ? 1 : 0

  name = "${var.prefix}-eks-access"
  role = local.role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSDescribe"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups"
        ]
        Resource = "*"
      },
      {
        Sid    = "EKSRunJob"
        Effect = "Allow"
        Action = [
          "eks:AccessKubernetesApi"
        ]
        Resource = "arn:aws:eks:*:${local.account_id}:cluster/*"
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
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM Policy - Lambda Invoke
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "lambda_access" {
  count = local.should_attach_policies ? 1 : 0

  name = "${var.prefix}-lambda-access"
  role = local.role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LambdaInvoke"
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          "arn:aws:lambda:*:${local.account_id}:function:${var.prefix}-*"
        ]
      },
      {
        Sid    = "LambdaManage"
        Effect = "Allow"
        Action = [
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:UpdateFunctionConfiguration",
          "lambda:CreateFunction",
          "lambda:DeleteFunction",
          "lambda:TagResource"
        ]
        Resource = [
          "arn:aws:lambda:*:${local.account_id}:function:${var.prefix}-*"
        ]
      },
      {
        Sid    = "LambdaPassRole"
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          "arn:aws:iam::${local.account_id}:role/${var.prefix}-*"
        ]
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "lambda.amazonaws.com"
          }
        }
      },
      {
        Sid    = "S3GetLambdaCode"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = var.lambda_code_bucket_arn != null ? [
          "${var.lambda_code_bucket_arn}/*"
        ] : [
          "arn:aws:s3:::${var.prefix}-lambda-code-*/*"
        ]
      },
      {
        Sid    = "EC2DescribeForVpcLambda"
        Effect = "Allow"
        Action = [
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM Policy - SSM Parameters
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "ssm_access" {
  count = local.should_attach_policies ? 1 : 0

  name = "${var.prefix}-ssm-access"
  role = local.role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SSMParameters"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:PutParameter",
          "ssm:DeleteParameter"
        ]
        Resource = "arn:aws:ssm:*:${local.account_id}:parameter/${var.prefix}/*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM Policy - S3 Access
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "s3_access" {
  count = local.should_attach_policies ? 1 : 0

  name = "${var.prefix}-s3-access"
  role = local.role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject"
        ]
        Resource = var.s3_bucket_arns
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM Policy - KMS
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
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = var.kms_key_arns
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
          "tag:TagResources",
          "tag:UntagResources",
          "tag:GetResources"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM Policy - DynamoDB (for notifications)
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "dynamodb_access" {
  count = local.should_attach_policies && var.dynamodb_table_arn != null ? 1 : 0

  name = "${var.prefix}-dynamodb-access"
  role = local.role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDBAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ]
        Resource = var.dynamodb_table_arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM Policy - SNS (for notifications)
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "sns_access" {
  count = local.should_attach_policies && var.sns_topic_arn != null ? 1 : 0

  name = "${var.prefix}-sns-access"
  role = local.role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SNSPublish"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.sns_topic_arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# EKS Access Entry - Grants Kubernetes API access to the destination role
# -----------------------------------------------------------------------------

resource "aws_eks_access_entry" "destination" {
  count = var.create_eks_access_entry && var.eks_cluster_name != null ? 1 : 0

  cluster_name  = var.eks_cluster_name
  principal_arn = local.role_arn
  type          = "STANDARD"

  tags = var.tags
}

resource "aws_eks_access_policy_association" "destination" {
  count = var.create_eks_access_entry && var.eks_cluster_name != null ? 1 : 0

  cluster_name  = var.eks_cluster_name
  principal_arn = local.role_arn
  policy_arn    = var.eks_access_policy_arn

  access_scope {
    type       = var.eks_access_scope_type
    namespaces = var.eks_access_scope_type == "namespace" ? var.eks_access_scope_namespaces : null
  }

  depends_on = [aws_eks_access_entry.destination]
}
