"""
Lambda function to execute SQL scripts from S3 on MySQL/Aurora databases.
Used by Step Functions: run_sql_lambda, run_sql_from_s3
"""

import boto3
import json
import logging
import os
import pymysql
from pymysql.constants import CLIENT
from pymysql.err import (
    ProgrammingError,
    DataError,
    IntegrityError,
    NotSupportedError,
    OperationalError
)

# Configure logging
logger = logging.getLogger()
log_level = os.environ.get('LOG_LEVEL', 'INFO')
logger.setLevel(getattr(logging, log_level))


def get_connection(credentials: dict, host: str, port: int, database: str):
    """
    Establish connection to MySQL/Aurora database.

    Args:
        credentials: Dict with 'username' and 'password' keys
        host: Database endpoint
        port: Database port
        database: Database name

    Returns:
        pymysql connection object or None if connection fails
    """
    try:
        conn = pymysql.connect(
            host=host,
            user=credentials["username"],
            passwd=credentials["password"],
            port=int(port),
            db=database,
            connect_timeout=10,
            read_timeout=300,
            write_timeout=300,
            client_flag=CLIENT.MULTI_STATEMENTS
        )
        return conn
    except OperationalError as e:
        logger.error(f"Failed to connect to database: {e}")
        return None


def get_db_cluster_info(cluster_identifier: str, region: str) -> dict:
    """
    Get database cluster endpoint and port.

    Args:
        cluster_identifier: RDS cluster identifier
        region: AWS region

    Returns:
        Dict with 'endpoint' and 'port' keys
    """
    rds_client = boto3.client("rds", region_name=region)
    response = rds_client.describe_db_clusters(DBClusterIdentifier=cluster_identifier)

    cluster = response["DBClusters"][0]
    return {
        "endpoint": cluster["Endpoint"],
        "port": cluster["Port"],
        "arn": cluster["DBClusterArn"]
    }


def get_secret(secret_id: str, region: str) -> dict:
    """
    Retrieve secret from AWS Secrets Manager.

    Args:
        secret_id: Secret ARN or name
        region: AWS region

    Returns:
        Parsed secret dict with 'username' and 'password' keys
    """
    secrets_client = boto3.client("secretsmanager", region_name=region)
    response = secrets_client.get_secret_value(SecretId=secret_id)
    return json.loads(response["SecretString"])


def get_sql_from_s3(bucket: str, key: str, region: str) -> str:
    """
    Download SQL script from S3.

    Args:
        bucket: S3 bucket name
        key: S3 object key
        region: AWS region

    Returns:
        SQL script content as string
    """
    s3_client = boto3.client("s3", region_name=region)
    response = s3_client.get_object(Bucket=bucket, Key=key)
    return response["Body"].read().decode("utf-8")


def execute_sql(conn, sql: str) -> dict:
    """
    Execute SQL statement(s) on the database.

    Args:
        conn: pymysql connection
        sql: SQL statement(s) to execute

    Returns:
        Dict with execution results
    """
    results = []

    with conn.cursor() as cursor:
        cursor.execute(sql)

        # Handle multiple result sets (MULTI_STATEMENTS)
        while True:
            if cursor.description:
                rows = cursor.fetchall()
                results.append({
                    "rowcount": cursor.rowcount,
                    "rows": rows[:100] if rows else []  # Limit output
                })
            else:
                results.append({
                    "rowcount": cursor.rowcount,
                    "rows": []
                })

            if not cursor.nextset():
                break

        conn.commit()

    return {
        "statement_count": len(results),
        "results": results
    }


def lambda_handler(event, context):
    """
    Lambda handler for SQL execution.

    Expected event structure:
    {
        "cluster": "my-cluster-identifier",
        "dbname": "mydb",
        "secretname": "arn:aws:secretsmanager:...",
        "bucketname": "my-bucket",  # Optional, for S3 scripts
        "key": "scripts/init.sql",  # Optional, for S3 scripts
        "sql": "SELECT 1"           # Optional, for direct SQL
    }
    """
    region = os.environ.get("AWS_REGION", "eu-central-1")

    # Extract parameters
    cluster_id = event["cluster"]
    database = event["dbname"]
    secret_name = event["secretname"]

    logger.info(f"Connecting to cluster: {cluster_id}, database: {database}")

    # Get cluster info
    cluster_info = get_db_cluster_info(cluster_id, region)
    logger.info(f"Cluster endpoint: {cluster_info['endpoint']}")

    # Get credentials
    credentials = get_secret(secret_name, region)

    # Get SQL to execute
    if "sql" in event:
        sql = event["sql"]
        logger.info("Executing direct SQL statement")
    elif "bucketname" in event and "key" in event:
        sql = get_sql_from_s3(event["bucketname"], event["key"], region)
        logger.info(f"Executing SQL from s3://{event['bucketname']}/{event['key']}")
    else:
        raise ValueError("Either 'sql' or 'bucketname'/'key' must be provided")

    # Connect and execute
    conn = get_connection(
        credentials,
        cluster_info["endpoint"],
        cluster_info["port"],
        database
    )

    if not conn:
        raise ValueError("Unable to connect to the database")

    try:
        logger.info("Connection established, executing SQL...")
        result = execute_sql(conn, sql)
        logger.info(f"Execution complete: {result['statement_count']} statement(s)")

        return {
            "statusCode": 200,
            "body": json.dumps({
                "status": "success",
                "cluster": cluster_id,
                "database": database,
                "result": result
            })
        }

    except (ProgrammingError, DataError, IntegrityError, NotSupportedError) as e:
        logger.error(f"SQL error: {e}")
        raise ValueError(f"SQL execution error: {e}")
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        raise
    finally:
        conn.close()
        logger.info("Connection closed")
