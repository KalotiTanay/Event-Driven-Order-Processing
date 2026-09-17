import json
import os
import sys
import unittest
from unittest.mock import MagicMock, patch

from botocore.exceptions import ClientError

os.environ["ORDERS_TABLE_NAME"] = "test-orders"
os.environ["INVENTORY_TABLE_NAME"] = "test-inventory"
os.environ["PAYMENT_QUEUE_URL"] = "https://sqs.test/payment"
os.environ["INVENTORY_FAILURES_QUEUE_URL"] = "https://sqs.test/inventory-failures"
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

with patch("boto3.resource"), patch("boto3.client"):
    import handler


def _sqs_event(order):
    return {"Records": [{"body": json.dumps(order)}]}


def _conditional_check_failed():
    return ClientError(
        {"Error": {"Code": "ConditionalCheckFailedException", "Message": "stock too low"}},
        "UpdateItem",
    )


class TestInventoryCheckHandler(unittest.TestCase):
    def setUp(self):
        # dynamodb.Table(...) is mocked generically, so orders_table and
        # inventory_table would otherwise resolve to the same MagicMock —
        # replace both with distinct instances so their behavior is independent.
        handler.orders_table = MagicMock()
        handler.inventory_table = MagicMock()
        handler.sqs.send_message = MagicMock()

    def test_sufficient_stock_reserves_and_forwards_to_payment(self):
        order = {"order_id": "o1", "items": [{"product_id": "prod-001", "quantity": 5}]}
        handler.lambda_handler(_sqs_event(order), None)

        status = handler.orders_table.update_item.call_args.kwargs["ExpressionAttributeValues"][":s"]
        self.assertEqual(status, "INVENTORY_RESERVED")
        handler.sqs.send_message.assert_called_once_with(
            QueueUrl=os.environ["PAYMENT_QUEUE_URL"], MessageBody=json.dumps(order)
        )

    def test_insufficient_stock_marks_out_of_stock_and_sends_to_dlq(self):
        handler.inventory_table.update_item.side_effect = _conditional_check_failed()
        order = {"order_id": "o2", "items": [{"product_id": "prod-003", "quantity": 5}]}
        handler.lambda_handler(_sqs_event(order), None)

        status = handler.orders_table.update_item.call_args.kwargs["ExpressionAttributeValues"][":s"]
        self.assertEqual(status, "OUT_OF_STOCK")
        sent_queue = handler.sqs.send_message.call_args.kwargs["QueueUrl"]
        self.assertEqual(sent_queue, os.environ["INVENTORY_FAILURES_QUEUE_URL"])

    def test_exact_boundary_quantity_succeeds(self):
        # Requested quantity == quantity_available should still pass (condition is >=).
        # The condition itself is evaluated server-side by DynamoDB; this test only
        # confirms our handler treats a non-error response as a success path.
        order = {"order_id": "o3", "items": [{"product_id": "prod-002", "quantity": 10}]}
        handler.lambda_handler(_sqs_event(order), None)

        status = handler.orders_table.update_item.call_args.kwargs["ExpressionAttributeValues"][":s"]
        self.assertEqual(status, "INVENTORY_RESERVED")


if __name__ == "__main__":
    unittest.main()
