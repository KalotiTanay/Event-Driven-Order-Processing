import json
import os
import sys
import unittest
from unittest.mock import MagicMock, patch

os.environ["ORDERS_TABLE_NAME"] = "test-orders"
os.environ["INVENTORY_TABLE_NAME"] = "test-inventory"
os.environ["ORDER_EVENTS_TOPIC_ARN"] = "arn:aws:sns:us-east-1:123456789012:order-events"
os.environ["PAYMENT_FAILURES_QUEUE_URL"] = "https://sqs.test/payment-failures"
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

with patch("boto3.resource"), patch("boto3.client"):
    import handler


def _sqs_event(order):
    return {"Records": [{"body": json.dumps(order)}]}


class TestPaymentProcessingHandler(unittest.TestCase):
    def setUp(self):
        handler.orders_table = MagicMock()
        handler.inventory_table = MagicMock()
        handler.sqs.send_message = MagicMock()
        handler.sns.publish = MagicMock()

    @patch("handler.random.random", return_value=0.0)  # below success rate -> payment succeeds
    def test_successful_payment_completes_order_and_publishes_event(self, _mock_random):
        order = {"order_id": "o1", "items": [{"product_id": "prod-001", "quantity": 2}]}
        handler.lambda_handler(_sqs_event(order), None)

        status = handler.orders_table.update_item.call_args.kwargs["ExpressionAttributeValues"][":s"]
        self.assertEqual(status, "COMPLETE")
        handler.sns.publish.assert_called_once()
        handler.inventory_table.update_item.assert_not_called()

    @patch("handler.random.random", return_value=1.0)  # above success rate -> payment fails
    def test_failed_payment_releases_inventory_and_sends_to_dlq(self, _mock_random):
        order = {"order_id": "o2", "items": [{"product_id": "prod-001", "quantity": 2}]}
        handler.lambda_handler(_sqs_event(order), None)

        status = handler.orders_table.update_item.call_args.kwargs["ExpressionAttributeValues"][":s"]
        self.assertEqual(status, "PAYMENT_FAILED")
        handler.inventory_table.update_item.assert_called_once()
        sent_queue = handler.sqs.send_message.call_args.kwargs["QueueUrl"]
        self.assertEqual(sent_queue, os.environ["PAYMENT_FAILURES_QUEUE_URL"])
        handler.sns.publish.assert_not_called()


if __name__ == "__main__":
    unittest.main()
