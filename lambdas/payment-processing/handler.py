import json
import logging
import os
import random
import time

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
sqs = boto3.client("sqs")
sns = boto3.client("sns")

ORDERS_TABLE = os.environ["ORDERS_TABLE_NAME"]
INVENTORY_TABLE = os.environ["INVENTORY_TABLE_NAME"]
ORDER_EVENTS_TOPIC_ARN = os.environ["ORDER_EVENTS_TOPIC_ARN"]
PAYMENT_FAILURES_QUEUE_URL = os.environ["PAYMENT_FAILURES_QUEUE_URL"]
PAYMENT_SUCCESS_RATE = float(os.environ.get("PAYMENT_SUCCESS_RATE", "0.8"))

orders_table = dynamodb.Table(ORDERS_TABLE)
inventory_table = dynamodb.Table(INVENTORY_TABLE)


def lambda_handler(event, context):
    for record in event["Records"]:
        _process_record(json.loads(record["body"]))
    return {"statusCode": 200}


def _process_record(order):
    order_id = order["order_id"]

    if _simulate_payment():
        _update_order_status(order_id, "COMPLETE")
        sns.publish(TopicArn=ORDER_EVENTS_TOPIC_ARN, Message=json.dumps(order), Subject="PaymentComplete")
        _log(order_id, "COMPLETE")
        return

    # Compensating transaction (Saga pattern) — payment failed after inventory
    # was already reserved, so give that stock back before failing the order.
    _release_inventory(order.get("items", []))
    _update_order_status(order_id, "PAYMENT_FAILED")
    sqs.send_message(
        QueueUrl=PAYMENT_FAILURES_QUEUE_URL,
        MessageBody=json.dumps({"order_id": order_id, "reason": "Simulated payment declined"}),
    )
    _log(order_id, "PAYMENT_FAILED")


def _simulate_payment():
    """Mocked payment gateway call — swap for a real provider integration later."""
    return random.random() < PAYMENT_SUCCESS_RATE


def _release_inventory(items):
    for item in items:
        inventory_table.update_item(
            Key={"product_id": item["product_id"]},
            UpdateExpression=(
                "SET quantity_available = quantity_available + :q, "
                "reserved_quantity = reserved_quantity - :q"
            ),
            ExpressionAttributeValues={":q": item["quantity"]},
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
        "stage": "payment",
        "order_id": order_id,
        "status": status,
        "timestamp": int(time.time()),
        **extra,
    }))
