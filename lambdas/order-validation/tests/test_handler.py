import json
import os
import sys
import unittest
from unittest.mock import MagicMock, patch

os.environ["ORDERS_TABLE_NAME"] = "test-orders"
os.environ["INVENTORY_TABLE_NAME"] = "test-inventory"
os.environ["INVENTORY_QUEUE_URL"] = "https://sqs.test/inventory-check"
os.environ["VALIDATION_FAILURES_QUEUE_URL"] = "https://sqs.test/validation-failures"
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

with patch("boto3.resource"), patch("boto3.client"):
    import handler


def _sqs_event(order):
    return {"Records": [{"body": json.dumps(order)}]}


class TestOrderValidationHandler(unittest.TestCase):
    def setUp(self):
        handler.orders_table.update_item = MagicMock()
        handler.inventory_table.get_item = MagicMock(return_value={"Item": {"product_id": "prod-001"}})
        handler.sqs.send_message = MagicMock()

    def test_valid_order_marks_validated_and_forwards(self):
        order = {"order_id": "o1", "items": [{"product_id": "prod-001", "quantity": 2}]}
        handler.lambda_handler(_sqs_event(order), None)

        status = handler.orders_table.update_item.call_args.kwargs["ExpressionAttributeValues"][":s"]
        self.assertEqual(status, "VALIDATED")
        handler.sqs.send_message.assert_called_once_with(
            QueueUrl=os.environ["INVENTORY_QUEUE_URL"], MessageBody=json.dumps(order)
        )

    def test_unknown_product_id_rejects_order(self):
        handler.inventory_table.get_item = MagicMock(return_value={})
        order = {"order_id": "o2", "items": [{"product_id": "prod-999", "quantity": 1}]}
        handler.lambda_handler(_sqs_event(order), None)

        status = handler.orders_table.update_item.call_args.kwargs["ExpressionAttributeValues"][":s"]
        self.assertEqual(status, "REJECTED")
        sent_queue = handler.sqs.send_message.call_args.kwargs["QueueUrl"]
        self.assertEqual(sent_queue, os.environ["VALIDATION_FAILURES_QUEUE_URL"])

    def test_zero_quantity_rejects_order(self):
        order = {"order_id": "o3", "items": [{"product_id": "prod-001", "quantity": 0}]}
        handler.lambda_handler(_sqs_event(order), None)

        status = handler.orders_table.update_item.call_args.kwargs["ExpressionAttributeValues"][":s"]
        self.assertEqual(status, "REJECTED")


if __name__ == "__main__":
    unittest.main()
