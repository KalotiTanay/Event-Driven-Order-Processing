output "orders_table_name" {
  value = aws_dynamodb_table.orders.name
}

output "inventory_table_name" {
  value = aws_dynamodb_table.inventory.name
}

output "order_validation_queue_url" {
  value = aws_sqs_queue.order_validation.url
}

output "api_endpoint" {
  description = "Base URL — POST {this}/orders to place an order"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "inventory_check_queue_url" {
  value = aws_sqs_queue.inventory_check.url
}

output "payment_queue_url" {
  value = aws_sqs_queue.payment.url
}

output "validation_failures_queue_url" {
  value = aws_sqs_queue.validation_failures.url
}

output "inventory_failures_queue_url" {
  value = aws_sqs_queue.inventory_failures.url
}

output "payment_failures_queue_url" {
  value = aws_sqs_queue.payment_failures.url
}

output "order_events_topic_arn" {
  value = aws_sns_topic.order_events.arn
}

output "ops_alerts_topic_arn" {
  value = aws_sns_topic.ops_alerts.arn
}

output "dashboard_url" {
  description = "Direct link to the CloudWatch pipeline dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}
