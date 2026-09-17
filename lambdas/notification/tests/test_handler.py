import json
import os
import sys
import unittest
from unittest.mock import MagicMock, patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

with patch("boto3.client"):
    import handler


def _sns_event(order):
    return {"Records": [{"Sns": {"Message": json.dumps(order)}}]}


class TestNotificationHandler(unittest.TestCase):
    def setUp(self):
        handler.ses.send_email = MagicMock()
        self._original_sender = handler.SENDER_EMAIL

    def tearDown(self):
        handler.SENDER_EMAIL = self._original_sender

    def test_logs_instead_of_sending_when_ses_not_configured(self):
        handler.SENDER_EMAIL = None
        order = {"order_id": "o1", "customer_id": "cust@example.com"}
        handler.lambda_handler(_sns_event(order), None)
        handler.ses.send_email.assert_not_called()

    def test_sends_email_when_ses_configured(self):
        handler.SENDER_EMAIL = "orders@example.com"
        order = {"order_id": "o2", "customer_id": "cust@example.com"}
        handler.lambda_handler(_sns_event(order), None)

        handler.ses.send_email.assert_called_once()
        self.assertEqual(handler.ses.send_email.call_args.kwargs["Source"], "orders@example.com")


if __name__ == "__main__":
    unittest.main()
