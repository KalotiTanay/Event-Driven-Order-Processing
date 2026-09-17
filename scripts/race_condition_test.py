"""
Manual integration test for EDOS-13.

Fires N concurrent order requests against a single product and confirms the
DynamoDB conditional write in the Inventory Check Lambda prevents overselling.
Run this AFTER `terraform apply`, against real deployed AWS resources — it is
not part of the unit test suite.

Usage:
    python3 race_condition_test.py <api_endpoint> <product_id> <num_requests>

Example (prod-002 starts with 10 units in stock):
    python3 race_condition_test.py https://abc123.execute-api.us-east-1.amazonaws.com prod-002 20
"""

import concurrent.futures
import sys

import requests


def place_order(api_endpoint, product_id):
    response = requests.post(
        f"{api_endpoint}/orders",
        json={"customer_id": "race-test", "items": [{"product_id": product_id, "quantity": 1}]},
    )
    return response.status_code


def main():
    api_endpoint, product_id, num_requests = sys.argv[1], sys.argv[2], int(sys.argv[3])

    with concurrent.futures.ThreadPoolExecutor(max_workers=num_requests) as executor:
        futures = [executor.submit(place_order, api_endpoint, product_id) for _ in range(num_requests)]
        statuses = [f.result() for f in concurrent.futures.as_completed(futures)]

    print(f"Fired {num_requests} concurrent requests for {product_id}")
    print(f"{statuses.count(202)} accepted at intake (202) — this just means they queued, not that they reserved stock")
    print()
    print("Wait a few seconds for the pipeline to drain, then check:")
    print(f"  aws dynamodb scan --table-name <inventory-table> --filter-expression 'product_id = :p' "
          f"--expression-attribute-values '{{\":p\":{{\"S\":\"{product_id}\"}}}}'")
    print("  -> quantity_available should never go negative")
    print("  aws dynamodb scan --table-name <orders-table> --filter-expression 'status = :s' "
          "--expression-attribute-values '{\":s\":{\"S\":\"INVENTORY_RESERVED\"}}'")
    print("  -> count of INVENTORY_RESERVED orders for this product should never exceed its starting stock")


if __name__ == "__main__":
    main()
