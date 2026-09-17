resource "aws_sqs_queue" "order_validation" {
  name                       = "${var.project_name}-${var.environment}-order-validation-queue"
  visibility_timeout_seconds = 30
}

resource "aws_sqs_queue" "inventory_check" {
  name                       = "${var.project_name}-${var.environment}-inventory-check-queue"
  visibility_timeout_seconds = 30
}

resource "aws_sqs_queue" "payment" {
  name                       = "${var.project_name}-${var.environment}-payment-queue"
  visibility_timeout_seconds = 30
}

resource "aws_sqs_queue" "validation_failures" {
  name = "${var.project_name}-${var.environment}-validation-failures"
}

resource "aws_sqs_queue" "inventory_failures" {
  name = "${var.project_name}-${var.environment}-inventory-failures"
}

resource "aws_sqs_queue" "payment_failures" {
  name = "${var.project_name}-${var.environment}-payment-failures"
}
