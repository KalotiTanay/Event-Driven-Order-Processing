import json
import logging
import os
import time
import uuid

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
sqs = boto3.client("sqs")

ORDERS_TABLE = os.environ["ORDERS_TABLE_NAME"]
VALIDATION_QUEUE_URL = os.environ["VALIDATION_QUEUE_URL"]

REQUIRED_FIELDS = ["customer_id", "items"]


def lambda_handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "Invalid JSON body"})

    error = _validate_shape(body)
    if error:
        _log(None, "REJECTED", reason=error)
        return _response(400, {"error": error})

    order_id = str(uuid.uuid4())
    now = int(time.time())

    dynamodb.Table(ORDERS_TABLE).put_item(
        Item={
            "order_id": order_id,
            "customer_id": body["customer_id"],
            "items": body["items"],
            "status": "PENDING",
            "created_at": now,
            "updated_at": now,
        }
    )

    sqs.send_message(
        QueueUrl=VALIDATION_QUEUE_URL,
        MessageBody=json.dumps(
            {"order_id": order_id, "customer_id": body["customer_id"], "items": body["items"]}
        ),
    )

    _log(order_id, "PENDING")
    return _response(202, {"order_id": order_id})

def _validate_shape(body):
    """Presence/shape checks only — business rules belong to the Validation Lambda."""
    missing = [f for f in REQUIRED_FIELDS if not body.get(f)]
    if missing:
        return f"Missing required field(s): {', '.join(missing)}"

    if not isinstance(body["items"], list) or len(body["items"]) == 0:
        return "items must be a non-empty list"

    return None


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def _log(order_id, status, **extra):
    logger.info(json.dumps({
        "stage": "intake",
        "order_id": order_id,
        "status": status,
        "timestamp": int(time.time()),
        **extra,
    }))
