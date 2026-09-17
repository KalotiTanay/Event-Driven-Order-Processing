import json
import logging
import os
import time

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
sqs = boto3.client("sqs")

ORDERS_TABLE = os.environ["ORDERS_TABLE_NAME"]
INVENTORY_TABLE = os.environ["INVENTORY_TABLE_NAME"]
INVENTORY_QUEUE_URL = os.environ["INVENTORY_QUEUE_URL"]
VALIDATION_FAILURES_QUEUE_URL = os.environ["VALIDATION_FAILURES_QUEUE_URL"]

orders_table = dynamodb.Table(ORDERS_TABLE)
inventory_table = dynamodb.Table(INVENTORY_TABLE)


def lambda_handler(event, context):
    for record in event["Records"]:
        _process_record(json.loads(record["body"]))
    return {"statusCode": 200}


def _process_record(order):
    order_id = order["order_id"]
    error = _validate_business_rules(order)

    if error:
        _update_order_status(order_id, "REJECTED")
        sqs.send_message(
            QueueUrl=VALIDATION_FAILURES_QUEUE_URL,
            MessageBody=json.dumps({"order_id": order_id, "reason": error}),
        )
        _log(order_id, "REJECTED", reason=error)
        return

    _update_order_status(order_id, "VALIDATED")
    sqs.send_message(QueueUrl=INVENTORY_QUEUE_URL, MessageBody=json.dumps(order))
    _log(order_id, "VALIDATED")


def _validate_business_rules(order):
    items = order.get("items", [])
    if not items:
        return "Order has no items"

    for item in items:
        product_id = item.get("product_id")
        quantity = item.get("quantity", 0)

        if quantity <= 0:
            return f"Invalid quantity for {product_id}: {quantity}"

        if "Item" not in inventory_table.get_item(Key={"product_id": product_id}):
            return f"Unknown product_id: {product_id}"

    return None


def _update_order_status(order_id, status):
    orders_table.update_item(
        Key={"order_id": order_id},
        UpdateExpression="SET #s = :s, updated_at = :u",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={":s": status, ":u": int(time.time())},
    )


def _log(order_id, status, **extra):
    logger.info(json.dumps({
        "stage": "validation",
        "order_id": order_id,
        "status": status,
        "timestamp": int(time.time()),
        **extra,
    }))
