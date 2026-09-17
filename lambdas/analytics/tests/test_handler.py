import json
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import handler


def _sns_event(order):
    return {"Records": [{"Sns": {"Message": json.dumps(order)}}]}


class TestAnalyticsHandler(unittest.TestCase):
    def test_logs_order_metrics(self):
        order = {
            "order_id": "o1",
            "customer_id": "cust-1",
            "items": [{"product_id": "prod-001", "quantity": 3}],
        }
        with self.assertLogs(handler.logger, level="INFO") as captured:
            handler.lambda_handler(_sns_event(order), None)

        logged = json.loads(captured.output[0].split(":", 2)[-1])
        self.assertEqual(logged["order_id"], "o1")
        self.assertEqual(logged["item_count"], 3)


if __name__ == "__main__":
    unittest.main()
