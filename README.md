# terraform-aws-refresh

Terraform module for cross-account AWS database and EFS refresh orchestration using Step Functions.

## Overview

This module deploys a complete infrastructure for automating database refresh operations from production to non-production environments across AWS accounts. It uses AWS Step Functions to orchestrate complex workflows including:

- Aurora/RDS cluster snapshot, share, and restore
- EFS backup and cross-account replication
- EKS job execution for data transformations
- Secret rotation and management

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Shared Services Account                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    Orchestrator Step Function                        │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐            │    │
│  │  │    DB    │  │   EFS    │  │   EKS    │  │  Utils   │            │    │
│  │  │ Modules  │  │ Modules  │  │ Modules  │  │ Modules  │            │    │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘            │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│                          AssumeRole (cross-account)                          │
└────────────────────────────────────┼────────────────────────────────────────┘
                                     │
          ┌──────────────────────────┼──────────────────────────┐
          │                          │                          │
          ▼                          ▼                          ▼
┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐
│   Source Account    │  │ Destination Account │  │ Destination Account │
│   (Production)      │  │   (Staging)         │  │   (Dev)             │
│                     │  │                     │  │                     │
│  • RDS Snapshots    │  │  • Restore Cluster  │  │  • Restore Cluster  │
│  • EFS Backups      │  │  • Lambda Helpers   │  │  • Lambda Helpers   │
│  • Secrets (read)   │  │  • EKS Jobs         │  │  • EKS Jobs         │
└─────────────────────┘  └─────────────────────┘  └─────────────────────┘
```

## Deployment Model

This module follows a **multi-deployment architecture** where each AWS account has its own Terraform deployment:

| Account | Module | Description |
|---------|--------|-------------|
| Shared Services | Root module | Orchestrator + Step Functions |
| Production | `modules/source-account` | IAM role for snapshot/backup access |
| Staging | `modules/destination-account` | IAM role + Lambda helpers |
| Dev | `modules/destination-account` | IAM role + Lambda helpers |

Each deployment has its own Terraform state and is applied independently.

## Deployment Order

1. **First**: Deploy `source-account` and `destination-account` modules in their respective accounts
2. **Then**: Deploy the root module in shared services, passing the role ARNs created in step 1

This order is required because the orchestrator needs to know the role ARNs to configure its assume-role permissions.

## Usage

### Step 1: Source Account (Production)

Deploy in your production account to grant snapshot/backup access:

```hcl
# deployments/production/main.tf

module "refresh_source" {
  source  = "KamorionLabs/refresh/aws//modules/source-account"
  version = "0.2.0"

  prefix                = "myapp-refresh"
  orchestrator_role_arn = "arn:aws:iam::000000000000:role/myapp-refresh-orchestrator"

  # Optional: Restrict KMS keys
  kms_key_arns = [
    "arn:aws:kms:eu-west-1:111111111111:key/xxx-xxx-xxx"
  ]

  tags = {
    Project     = "database-refresh"
    Environment = "production"
  }
}

output "role_arn" {
  value = module.refresh_source.role_arn
}
```

**Using an existing role:**

```hcl
module "refresh_source" {
  source  = "KamorionLabs/refresh/aws//modules/source-account"
  version = "0.2.0"

  prefix                = "myapp-refresh"
  orchestrator_role_arn = "arn:aws:iam::000000000000:role/myapp-refresh-orchestrator"

  # Use existing role instead of creating one
  create_role       = false
  existing_role_arn = "arn:aws:iam::111111111111:role/my-existing-role"
  existing_role_name = "my-existing-role"
  attach_policies   = true  # Attach refresh policies to existing role
}
```

### Step 2: Destination Account(s) (Staging, Dev, etc.)

Deploy in each non-production account:

```hcl
# deployments/staging/main.tf

module "refresh_destination" {
  source  = "KamorionLabs/refresh/aws//modules/destination-account"
  version = "0.2.0"

  prefix                = "myapp-refresh"
  orchestrator_role_arn = "arn:aws:iam::000000000000:role/myapp-refresh-orchestrator"

  # Lambda configuration
  deploy_lambdas = true
  vpc_id         = "vpc-xxx"
  subnet_ids     = ["subnet-xxx", "subnet-yyy"]

  # EFS configuration (optional)
  enable_efs              = true
  efs_access_point_arn    = "arn:aws:elasticfilesystem:eu-west-1:222222222222:access-point/fsap-xxx"
  efs_local_mount_path    = "/mnt/efs"

  # EKS Access Entry (optional)
  create_eks_access_entry = true
  eks_cluster_name        = "my-cluster"
  eks_access_policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  tags = {
    Project     = "database-refresh"
    Environment = "staging"
  }
}

output "role_arn" {
  value = module.refresh_destination.role_arn
}
```

**Using an existing role:**

```hcl
module "refresh_destination" {
  source  = "KamorionLabs/refresh/aws//modules/destination-account"
  version = "0.2.0"

  prefix                = "myapp-refresh"
  orchestrator_role_arn = "arn:aws:iam::000000000000:role/myapp-refresh-orchestrator"

  # Use existing role
  create_role        = false
  existing_role_arn  = "arn:aws:iam::222222222222:role/my-existing-role"
  existing_role_name = "my-existing-role"
  attach_policies    = true

  # Lambda and other config...
  deploy_lambdas = true
  vpc_id         = "vpc-xxx"
  subnet_ids     = ["subnet-xxx", "subnet-yyy"]
}
```

### Step 3: Shared Services Account (Orchestrator)

Deploy after the source and destination roles exist:

```hcl
# deployments/shared-services/main.tf

module "refresh" {
  source  = "KamorionLabs/refresh/aws"
  version = "0.2.0"

  prefix = "myapp-refresh"

  # Pass the ARNs of roles created in step 1 and 2
  source_role_arns = [
    "arn:aws:iam::111111111111:role/myapp-refresh-source-role"
  ]

  destination_role_arns = [
    "arn:aws:iam::222222222222:role/myapp-refresh-destination-role",  # staging
    "arn:aws:iam::333333333333:role/myapp-refresh-destination-role"   # dev
  ]

  tags = {
    Project     = "database-refresh"
    Environment = "shared-services"
  }
}
```

## Step Functions Modules

### Database (`modules/step-functions/db`)

| Workflow | Description |
|----------|-------------|
| `configure_s3_integration` | Configure S3 integration for Aurora MySQL |
| `create_instance` | Create RDS instance in a cluster |
| `create_manual_snapshot` | Create manual cluster snapshot |
| `delete_cluster` | Delete Aurora cluster and instances |
| `enable_master_secret` | Enable Secrets Manager for master credentials |
| `ensure_cluster_available` | Wait for cluster to be available |
| `ensure_cluster_not_exists` | Ensure cluster is deleted before restore |
| `list_shared_snapshots` | List snapshots shared from source account |
| `rename_cluster` | Rename cluster with blue/green support |
| `restore_cluster` | Restore cluster from snapshot |
| `rotate_secrets` | Rotate database secrets |
| `run_mysqldump_on_eks` | Run mysqldump via EKS job |
| `run_mysqlimport_on_eks` | Run mysqlimport via EKS job |
| `run_sql_from_s3` | Execute SQL scripts from S3 |
| `run_sql_lambda` | Execute SQL via Lambda |
| `share_snapshot` | Share snapshot with destination account |
| `stop_cluster` | Stop Aurora cluster |

### EFS (`modules/step-functions/efs`)

| Workflow | Description |
|----------|-------------|
| `create_filesystem` | Create new EFS filesystem |
| `delete_filesystem` | Delete EFS filesystem and mount targets |
| `get_subpath_and_store_in_ssm` | Find backup restore directory and store in SSM |
| `restore_from_backup` | Restore EFS from AWS Backup |
| `setup_cross_account_replication` | Setup cross-account EFS replication |
| `wait_replication_complete` | Wait for replication to complete |

### EKS (`modules/step-functions/eks`)

| Workflow | Description |
|----------|-------------|
| `manage_storage` | Manage EFS PV/PVC for EKS |
| `scale_nodegroup_asg` | Scale EKS nodegroup ASG |

### Utils (`modules/step-functions/utils`)

| Workflow | Description |
|----------|-------------|
| `cleanup_and_stop` | Cleanup resources and stop refresh |
| `notify` | Send notifications (SNS/DynamoDB) |
| `prepare_refresh` | Prepare refresh execution context |
| `run_archive_job` | Run archive/backup job |
| `tag_resources` | Tag AWS resources |

## Root Module Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `prefix` | Prefix for all resource names | `string` | `"refresh"` | no |
| `tags` | Tags to apply to all resources | `map(string)` | `{}` | no |
| `source_role_arns` | List of IAM role ARNs in source accounts | `list(string)` | - | yes |
| `destination_role_arns` | List of IAM role ARNs in destination accounts | `list(string)` | - | yes |
| `enable_step_functions_logging` | Enable CloudWatch logging for Step Functions | `bool` | `true` | no |
| `log_retention_days` | CloudWatch log retention in days | `number` | `30` | no |
| `enable_xray_tracing` | Enable X-Ray tracing for Step Functions | `bool` | `false` | no |

## Root Module Outputs

| Name | Description |
|------|-------------|
| `orchestrator_role_arn` | ARN of the orchestrator IAM role |
| `orchestrator_role_name` | Name of the orchestrator IAM role |
| `orchestrator_arn` | ARN of the main orchestrator Step Function |
| `orchestrator_name` | Name of the main orchestrator Step Function |
| `step_functions_db` | Map of database Step Functions ARNs |
| `step_functions_efs` | Map of EFS Step Functions ARNs |
| `step_functions_eks` | Map of EKS Step Functions ARNs |
| `step_functions_utils` | Map of Utils Step Functions ARNs |
| `all_step_function_arns` | Consolidated map of all Step Function ARNs |

## IAM Permissions

### Orchestrator Role (Shared Services Account)

The orchestrator role can assume roles in source and destination accounts and execute Step Functions.

### Source Account Role

Permissions for:
- RDS: Describe clusters/snapshots, create/copy/share snapshots
- KMS: Encrypt/decrypt for snapshot operations
- EFS: Describe filesystems, read backup metadata
- Secrets Manager: Read secrets
- Tagging: Read resource tags

### Destination Account Role

Full permissions for:
- RDS: All operations for restore and management
- Secrets Manager: Create, update, rotate secrets
- EFS: All operations for restore and management
- EKS: Describe clusters, run Kubernetes jobs
- Lambda: Invoke helper functions
- S3: Read/write for SQL scripts and backups
- SSM: Parameter store for configuration
- Backup: Restore operations

## Lambda Functions

The destination-account module includes Lambda helpers:

| Function | Description |
|----------|-------------|
| `run-sql` | Execute SQL statements on Aurora MySQL |
| `get-efs-subpath` | Find the restore directory in EFS backup |

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |

## License

Apache 2.0

## Authors

KamorionLabs
