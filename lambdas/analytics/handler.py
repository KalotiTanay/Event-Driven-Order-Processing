import json
import logging
import time

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    for record in event["Records"]:
        order = json.loads(record["Sns"]["Message"])
        _log_metrics(order)
    return {"statusCode": 200}


def _log_metrics(order):
    item_count = sum(item.get("quantity", 0) for item in order.get("items", []))
    logger.info(json.dumps({
        "stage": "analytics",
        "order_id": order["order_id"],
        "status": "RECORDED",
        "timestamp": int(time.time()),
        "customer_id": order.get("customer_id"),
        "item_count": item_count,
    }))
