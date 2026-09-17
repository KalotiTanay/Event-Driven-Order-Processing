import json
import os
import sys
import unittest
from unittest.mock import MagicMock, patch

os.environ["ORDERS_TABLE_NAME"] = "test-orders"
os.environ["VALIDATION_QUEUE_URL"] = "https://sqs.test/queue"
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

with patch("boto3.resource"), patch("boto3.client"):
    import handler


class TestOrderIntakeHandler(unittest.TestCase):
    def setUp(self):
        handler.dynamodb.Table = MagicMock(return_value=MagicMock())
        handler.sqs.send_message = MagicMock()

    def test_valid_payload_returns_202_with_order_id(self):
        event = {
            "body": json.dumps(
                {"customer_id": "cust-1", "items": [{"product_id": "prod-001", "quantity": 2}]}
            )
        }
        response = handler.lambda_handler(event, None)
        self.assertEqual(response["statusCode"], 202)
        self.assertIn("order_id", json.loads(response["body"]))

    def test_missing_required_field_returns_400(self):
        event = {"body": json.dumps({"items": [{"product_id": "prod-001", "quantity": 2}]})}
        response = handler.lambda_handler(event, None)
        self.assertEqual(response["statusCode"], 400)

    def test_empty_items_returns_400(self):
        event = {"body": json.dumps({"customer_id": "cust-1", "items": []})}
        response = handler.lambda_handler(event, None)
        self.assertEqual(response["statusCode"], 400)


if __name__ == "__main__":
    unittest.main()
