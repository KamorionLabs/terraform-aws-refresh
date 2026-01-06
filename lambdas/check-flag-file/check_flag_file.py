"""
Lambda function to manage flag files for EFS replication verification.
Used to verify that cross-account EFS replication is working correctly
by writing a flag file on source and checking its presence on destination.

Actions:
  - write: Create a flag file with timestamp and UUID
  - check: Verify flag file exists and return its content
  - delete: Remove the flag file

Used by Step Functions: verify_replication_sync
"""

import json
import logging
import os
import uuid
from datetime import datetime, timezone

# Configure logging
logger = logging.getLogger()
log_level = os.environ.get('LOG_LEVEL', 'INFO')
logger.setLevel(getattr(logging, log_level))

# EFS mount point (configured in Lambda)
EFS_MOUNT_PATH = os.environ.get('EFS_MOUNT_PATH', '/mnt/efs')
FLAG_FILE_PREFIX = ".replication-check-"


def lambda_handler(event, context):
    """
    Lambda handler for flag file operations.

    Expected event structure:
    {
        "action": "write" | "check" | "delete",
        "flag_id": "optional-custom-id",  # Auto-generated UUID if not provided for write
        "timeout_seconds": 300,  # For check action - max age of flag file to consider valid
        "subpath": "optional/subpath"  # Optional subdirectory within EFS
    }

    Returns:
    {
        "statusCode": 200,
        "body": {
            "action": "write|check|delete",
            "flag_id": "the-flag-id",
            "flag_path": "/mnt/efs/.replication-check-xxx",
            "content": {...},  # For write/check
            "exists": true|false,  # For check
            "valid": true|false  # For check - whether content matches and is recent
        }
    }
    """
    action = event.get("action", "check")
    flag_id = event.get("flag_id")
    subpath = event.get("subpath", "")
    timeout_seconds = event.get("timeout_seconds", 300)

    # Build the base path
    base_path = os.path.join(EFS_MOUNT_PATH, subpath) if subpath else EFS_MOUNT_PATH

    logger.info(f"Action: {action}, Flag ID: {flag_id}, Base path: {base_path}")

    try:
        if action == "write":
            return write_flag_file(base_path, flag_id)
        elif action == "check":
            return check_flag_file(base_path, flag_id, timeout_seconds)
        elif action == "delete":
            return delete_flag_file(base_path, flag_id)
        else:
            return error_response(400, "INVALID_ACTION", f"Unknown action: {action}")

    except FileNotFoundError as e:
        logger.error(f"Path not found: {e}")
        return error_response(404, "PATH_NOT_FOUND", str(e))
    except PermissionError as e:
        logger.error(f"Permission denied: {e}")
        return error_response(403, "PERMISSION_DENIED", str(e))
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return error_response(500, "INTERNAL_ERROR", str(e))


def write_flag_file(base_path: str, flag_id: str = None) -> dict:
    """Create a flag file with timestamp and UUID."""
    if not flag_id:
        flag_id = str(uuid.uuid4())[:8]

    flag_filename = f"{FLAG_FILE_PREFIX}{flag_id}"
    flag_path = os.path.join(base_path, flag_filename)

    # Ensure base path exists
    if not os.path.exists(base_path):
        logger.warning(f"Base path does not exist, creating: {base_path}")
        os.makedirs(base_path, exist_ok=True)

    # Generate content
    content = {
        "flag_id": flag_id,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "created_by": "verify_replication_sync",
        "uuid": str(uuid.uuid4())
    }

    # Write flag file
    with open(flag_path, 'w') as f:
        json.dump(content, f)

    logger.info(f"Created flag file: {flag_path}")

    return {
        "statusCode": 200,
        "body": json.dumps({
            "action": "write",
            "flag_id": flag_id,
            "flag_path": flag_path,
            "content": content
        })
    }


def check_flag_file(base_path: str, flag_id: str, timeout_seconds: int = 300) -> dict:
    """Check if flag file exists and validate its content."""
    if not flag_id:
        return error_response(400, "MISSING_FLAG_ID", "flag_id is required for check action")

    flag_filename = f"{FLAG_FILE_PREFIX}{flag_id}"
    flag_path = os.path.join(base_path, flag_filename)

    exists = os.path.exists(flag_path)
    content = None
    valid = False
    age_seconds = None

    if exists:
        try:
            with open(flag_path, 'r') as f:
                content = json.load(f)

            # Check if the flag file is recent enough
            created_at = datetime.fromisoformat(content.get("created_at", ""))
            now = datetime.now(timezone.utc)
            age = now - created_at
            age_seconds = age.total_seconds()

            valid = age_seconds <= timeout_seconds

            logger.info(f"Flag file found: {flag_path}, age: {age_seconds}s, valid: {valid}")
        except (json.JSONDecodeError, ValueError) as e:
            logger.warning(f"Invalid flag file content: {e}")
            content = {"error": str(e)}
            valid = False
    else:
        logger.info(f"Flag file not found: {flag_path}")

    return {
        "statusCode": 200,
        "body": json.dumps({
            "action": "check",
            "flag_id": flag_id,
            "flag_path": flag_path,
            "exists": exists,
            "valid": valid,
            "content": content,
            "age_seconds": age_seconds
        })
    }


def delete_flag_file(base_path: str, flag_id: str) -> dict:
    """Delete a flag file."""
    if not flag_id:
        return error_response(400, "MISSING_FLAG_ID", "flag_id is required for delete action")

    flag_filename = f"{FLAG_FILE_PREFIX}{flag_id}"
    flag_path = os.path.join(base_path, flag_filename)

    deleted = False
    if os.path.exists(flag_path):
        os.remove(flag_path)
        deleted = True
        logger.info(f"Deleted flag file: {flag_path}")
    else:
        logger.info(f"Flag file not found (already deleted?): {flag_path}")

    return {
        "statusCode": 200,
        "body": json.dumps({
            "action": "delete",
            "flag_id": flag_id,
            "flag_path": flag_path,
            "deleted": deleted
        })
    }


def error_response(status_code: int, error_code: str, message: str) -> dict:
    """Generate an error response."""
    return {
        "statusCode": status_code,
        "body": json.dumps({
            "error": error_code,
            "message": message
        })
    }
