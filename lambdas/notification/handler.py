import json
import logging
import os
import time

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ses = boto3.client("ses")
SENDER_EMAIL = os.environ.get("SES_SENDER_EMAIL")  # unset -> log instead of sending (SES sandbox-safe for MVP)


def lambda_handler(event, context):
    for record in event["Records"]:
        order = json.loads(record["Sns"]["Message"])
        _notify(order)
    return {"statusCode": 200}


def _notify(order):
    order_id = order["order_id"]
    customer_id = order.get("customer_id", "unknown")

    if not SENDER_EMAIL:
        _log(order_id, "SIMULATED", customer_id=customer_id)
        return

    ses.send_email(
        Source=SENDER_EMAIL,
        Destination={"ToAddresses": [_lookup_customer_email(customer_id)]},
        Message={
            "Subject": {"Data": f"Order {order_id} confirmed"},
            "Body": {"Text": {"Data": f"Your order {order_id} has been placed and paid successfully."}},
        },
    )
    _log(order_id, "SENT", customer_id=customer_id)


def _lookup_customer_email(customer_id):
    # Placeholder — a real system would look this up from a Customers table.
    # For MVP, customer_id is treated as the destination address directly.
    return customer_id


def _log(order_id, status, **extra):
    logger.info(json.dumps({
        "stage": "notification",
        "order_id": order_id,
        "status": status,
        "timestamp": int(time.time()),
        **extra,
    }))
