"""
Lambda function to find the backup restore directory in an EFS filesystem.
When AWS Backup restores an EFS, it creates a directory like 'aws-backup-restore_<timestamp>'.
This function finds that directory and returns its path.

Used by Step Functions: get_subpath_and_store_in_ssm
"""

import json
import logging
import os

# Configure logging
logger = logging.getLogger()
log_level = os.environ.get('LOG_LEVEL', 'INFO')
logger.setLevel(getattr(logging, log_level))

# EFS mount point (configured in Lambda)
EFS_MOUNT_PATH = "/mnt/efs"
BACKUP_PREFIX = "aws-backup-restore_"


def lambda_handler(event, context):
    """
    Lambda handler to find EFS backup restore directory.

    Expected event structure:
    {
        "expected_prefix": "aws-backup-restore_"  # Optional, defaults to standard prefix
    }

    Returns:
    {
        "statusCode": 200,
        "body": {
            "subpath": "aws-backup-restore_2024-01-15T10-30-00",
            "full_path": "/mnt/efs/aws-backup-restore_2024-01-15T10-30-00"
        }
    }
    """
    prefix = event.get("expected_prefix", BACKUP_PREFIX)

    logger.info(f"Scanning {EFS_MOUNT_PATH} for directories starting with '{prefix}'")

    try:
        # List all items in the EFS mount
        items = os.listdir(EFS_MOUNT_PATH)
        logger.info(f"Found {len(items)} items in EFS root")

        # Filter for backup restore directories
        backup_dirs = []
        for item in items:
            item_path = os.path.join(EFS_MOUNT_PATH, item)
            if item.startswith(prefix) and os.path.isdir(item_path):
                backup_dirs.append(item)
                logger.info(f"Found backup directory: {item}")

        # Validate results
        if len(backup_dirs) == 0:
            logger.error(f"No backup restore directory found with prefix '{prefix}'")
            raise FileNotFoundError(f"No backup restore directory found with prefix '{prefix}'")

        if len(backup_dirs) > 1:
            logger.error(f"Multiple backup directories found: {backup_dirs}")
            raise ValueError(f"Multiple backup directories found. Expected 1, found {len(backup_dirs)}: {backup_dirs}")

        # Return the single backup directory
        subpath = backup_dirs[0]
        full_path = os.path.join(EFS_MOUNT_PATH, subpath)

        logger.info(f"Successfully found backup directory: {subpath}")

        return {
            "statusCode": 200,
            "body": json.dumps({
                "subpath": subpath,
                "full_path": full_path
            })
        }

    except FileNotFoundError as e:
        logger.error(f"EFS mount not accessible: {e}")
        return {
            "statusCode": 404,
            "body": json.dumps({
                "error": "EFS_NOT_FOUND",
                "message": str(e)
            })
        }
    except PermissionError as e:
        logger.error(f"Permission denied accessing EFS: {e}")
        return {
            "statusCode": 403,
            "body": json.dumps({
                "error": "PERMISSION_DENIED",
                "message": str(e)
            })
        }
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return {
            "statusCode": 500,
            "body": json.dumps({
                "error": "INTERNAL_ERROR",
                "message": str(e)
            })
        }
