# -----------------------------------------------------------------------------
# Lambda Functions for Source Account
# -----------------------------------------------------------------------------

locals {
  python_version      = "3.11"
  python_version_long = "python${local.python_version}"
  lambdas_path        = "${path.module}/../../lambdas"

  # EFS lambda functions (only deployed if enable_efs and deploy_lambdas are true)
  lambda_functions_efs = var.deploy_lambdas && var.enable_efs ? {
    "check-flag-file" = {
      path             = "${local.lambdas_path}/check-flag-file/check_flag_file.py"
      handler          = "check_flag_file.lambda_handler"
      timeout          = 60
      memory_size      = 128
      description      = "Manage replication flag file in EFS (write/check/delete)"
      efs_access_point = true
    }
  } : {}
}

# -----------------------------------------------------------------------------
# Lambda Functions - Archive
# -----------------------------------------------------------------------------

data "archive_file" "lambda_functions" {
  for_each = local.lambda_functions_efs

  type             = "zip"
  source_file      = each.value.path
  output_file_mode = "0666"
  output_path      = "${local.lambdas_path}/${each.key}.zip"
}

# -----------------------------------------------------------------------------
# Lambda Functions - Deployment (direct upload, no S3)
# -----------------------------------------------------------------------------

resource "aws_lambda_function" "functions" {
  for_each = data.archive_file.lambda_functions

  function_name    = "${var.prefix}-${each.key}"
  description      = lookup(local.lambda_functions_efs[each.key], "description", "")
  role             = aws_iam_role.lambda[0].arn
  filename         = each.value.output_path
  source_code_hash = each.value.output_base64sha256
  handler          = local.lambda_functions_efs[each.key].handler
  runtime          = local.python_version_long
  architectures    = ["arm64"]
  timeout          = lookup(local.lambda_functions_efs[each.key], "timeout", 300)
  memory_size      = lookup(local.lambda_functions_efs[each.key], "memory_size", 128)

  vpc_config {
    security_group_ids = var.create_lambda_security_group ? [aws_security_group.lambda[0].id] : var.lambda_security_group_ids
    subnet_ids         = var.lambda_subnet_ids
  }

  dynamic "file_system_config" {
    for_each = lookup(local.lambda_functions_efs[each.key], "efs_access_point", false) && var.efs_access_point_arn != null ? [1] : []
    content {
      arn              = var.efs_access_point_arn
      local_mount_path = "/mnt/efs"
    }
  }

  environment {
    variables = {
      LOG_LEVEL      = var.lambda_log_level
      EFS_MOUNT_PATH = "/mnt/efs"
    }
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy.lambda[0],
    aws_cloudwatch_log_group.lambda
  ]
}

# -----------------------------------------------------------------------------
# Lambda IAM Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "lambda" {
  count = var.deploy_lambdas && var.enable_efs ? 1 : 0

  name = "${var.prefix}-source-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "lambda" {
  count = var.deploy_lambdas && var.enable_efs ? 1 : 0

  name = "${var.prefix}-source-lambda-policy"
  role = aws_iam_role.lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:${local.account_id}:log-group:/aws/lambda/${var.prefix}-*:*"
      },
      {
        Sid    = "VPCAccess"
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ]
        Resource = "*"
      },
      {
        Sid    = "EFSAccess"
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRead",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeAccessPoints",
          "elasticfilesystem:DescribeMountTargets"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Lambda Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "lambda" {
  count = var.deploy_lambdas && var.enable_efs && var.create_lambda_security_group ? 1 : 0

  name        = "${var.prefix}-source-lambda-sg"
  description = "Security group for Lambda functions in source account"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.prefix}-source-lambda-sg"
  })
}

resource "aws_security_group_rule" "lambda_https_egress" {
  count = var.deploy_lambdas && var.enable_efs && var.create_lambda_security_group ? 1 : 0

  security_group_id = aws_security_group.lambda[0].id
  type              = "egress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTPS outbound for AWS APIs"
}

resource "aws_security_group_rule" "lambda_nfs_egress" {
  count = var.deploy_lambdas && var.enable_efs && var.create_lambda_security_group ? 1 : 0

  security_group_id = aws_security_group.lambda[0].id
  type              = "egress"
  protocol          = "tcp"
  from_port         = 2049
  to_port           = 2049
  cidr_blocks       = var.efs_cidr_blocks
  description       = "Allow NFS outbound to EFS"
}

# -----------------------------------------------------------------------------
# CloudWatch Log Groups
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "lambda" {
  for_each = local.lambda_functions_efs

  name              = "/aws/lambda/${var.prefix}-${each.key}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}
