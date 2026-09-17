import json
import logging
import os
import time

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
sqs = boto3.client("sqs")

ORDERS_TABLE = os.environ["ORDERS_TABLE_NAME"]
INVENTORY_TABLE = os.environ["INVENTORY_TABLE_NAME"]
PAYMENT_QUEUE_URL = os.environ["PAYMENT_QUEUE_URL"]
INVENTORY_FAILURES_QUEUE_URL = os.environ["INVENTORY_FAILURES_QUEUE_URL"]

orders_table = dynamodb.Table(ORDERS_TABLE)
inventory_table = dynamodb.Table(INVENTORY_TABLE)


def lambda_handler(event, context):
    for record in event["Records"]:
        _process_record(json.loads(record["body"]))
    return {"statusCode": 200}


def _process_record(order):
    order_id = order["order_id"]
    reserved = []

    for item in order.get("items", []):
        product_id, quantity = item["product_id"], item["quantity"]

        if _reserve_stock(product_id, quantity):
            reserved.append((product_id, quantity))
            continue

        # Insufficient stock partway through a multi-item order — release
        # anything already reserved for this order before failing it out.
        _release_stock(reserved)
        _update_order_status(order_id, "OUT_OF_STOCK")
        sqs.send_message(
            QueueUrl=INVENTORY_FAILURES_QUEUE_URL,
            MessageBody=json.dumps({"order_id": order_id, "reason": f"Insufficient stock for {product_id}"}),
        )
        _log(order_id, "OUT_OF_STOCK", product_id=product_id)
        return

    _update_order_status(order_id, "INVENTORY_RESERVED")
    sqs.send_message(QueueUrl=PAYMENT_QUEUE_URL, MessageBody=json.dumps(order))
    _log(order_id, "INVENTORY_RESERVED")


def _reserve_stock(product_id, quantity):
    """Atomic conditional decrement — prevents overselling under concurrent orders."""
    try:
        inventory_table.update_item(
            Key={"product_id": product_id},
            UpdateExpression=(
                "SET quantity_available = quantity_available - :q, "
                "reserved_quantity = reserved_quantity + :q"
            ),
            ConditionExpression="quantity_available >= :q",
            ExpressionAttributeValues={":q": quantity},
        )
        return True
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return False
        raise


def _release_stock(reserved_items):
    for product_id, quantity in reserved_items:
        inventory_table.update_item(
            Key={"product_id": product_id},
            UpdateExpression=(
                "SET quantity_available = quantity_available + :q, "
                "reserved_quantity = reserved_quantity - :q"
            ),
            ExpressionAttributeValues={":q": quantity},
        )


def _update_order_status(order_id, status):
    orders_table.update_item(
        Key={"order_id": order_id},
        UpdateExpression="SET #s = :s, updated_at = :u",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={":s": status, ":u": int(time.time())},
    )


def _log(order_id, status, **extra):
    logger.info(json.dumps({
        "stage": "inventory",
        "order_id": order_id,
        "status": status,
        "timestamp": int(time.time()),
        **extra,
    }))
