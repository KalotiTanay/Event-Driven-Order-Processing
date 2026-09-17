resource "aws_dynamodb_table" "orders" {
  name         = "${var.project_name}-${var.environment}-orders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "order_id"

  attribute {
    name = "order_id"
    type = "S"
  }
}

resource "aws_dynamodb_table" "inventory" {
  name         = "${var.project_name}-${var.environment}-inventory"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "product_id"

  attribute {
    name = "product_id"
    type = "S"
  }
}

# Sample products to test pipeline.
locals {
  sample_products = {
    "prod-001" = 50
    "prod-002" = 10
    "prod-003" = 0 # testing the OUT_OF_STOCK path
  }
}

resource "aws_dynamodb_table_item" "sample_products" {
  for_each   = local.sample_products
  table_name = aws_dynamodb_table.inventory.name
  hash_key   = aws_dynamodb_table.inventory.hash_key

  item = jsonencode({
    product_id         = { S = each.key }
    quantity_available = { N = tostring(each.value) }
    reserved_quantity  = { N = "0" }
  })
}
