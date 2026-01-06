# -----------------------------------------------------------------------------
# Lambda Code Module
# Packages and uploads Lambda code to S3 for dynamic creation by Step Functions
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.id

  # Lambda functions to package (EFS-related only, MySQL lambdas are deployed directly)
  lambda_functions = {
    "check-flag-file" = {
      source_file = "${path.module}/../../lambdas/check-flag-file/check_flag_file.py"
      handler     = "check_flag_file.lambda_handler"
      description = "Manage replication flag file in EFS (write/check/delete)"
    }
    "get-efs-subpath" = {
      source_file = "${path.module}/../../lambdas/get-efs-subpath/get_efs_subpath.py"
      handler     = "get_efs_subpath.lambda_handler"
      description = "Find EFS restore subpath from AWS Backup"
    }
  }
}

# -----------------------------------------------------------------------------
# S3 Bucket for Lambda Code
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "lambda_code" {
  bucket = "${var.prefix}-lambda-code-${local.account_id}"

  tags = merge(var.tags, {
    Name    = "${var.prefix}-lambda-code"
    Purpose = "Lambda code storage for Step Functions dynamic deployment"
  })
}

resource "aws_s3_bucket_versioning" "lambda_code" {
  bucket = aws_s3_bucket.lambda_code.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_code" {
  bucket = aws_s3_bucket.lambda_code.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "lambda_code" {
  bucket = aws_s3_bucket.lambda_code.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# S3 Bucket Policy for Cross-Account Access
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_policy" "lambda_code" {
  count  = length(var.cross_account_role_arns) > 0 ? 1 : 0
  bucket = aws_s3_bucket.lambda_code.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountGetObject"
        Effect = "Allow"
        Principal = {
          AWS = var.cross_account_role_arns
        }
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.lambda_code.arn}/*"
      },
      {
        Sid    = "AllowCrossAccountListBucket"
        Effect = "Allow"
        Principal = {
          AWS = var.cross_account_role_arns
        }
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.lambda_code.arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Package Lambda Code
# -----------------------------------------------------------------------------

data "archive_file" "lambda_functions" {
  for_each = local.lambda_functions

  type             = "zip"
  source_file      = each.value.source_file
  output_file_mode = "0666"
  output_path      = "${path.module}/../../lambdas/${each.key}.zip"
}

# -----------------------------------------------------------------------------
# Upload Lambda Code to S3
# -----------------------------------------------------------------------------

resource "aws_s3_object" "lambda_code" {
  for_each = data.archive_file.lambda_functions

  bucket = aws_s3_bucket.lambda_code.id
  key    = "lambdas/${each.key}.zip"
  source = each.value.output_path
  etag   = each.value.output_md5

  tags = merge(var.tags, {
    LambdaFunction = each.key
  })
}
