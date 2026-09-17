resource "aws_sns_topic" "order_events" {
  name = "${var.project_name}-${var.environment}-order-events-topic"
}

resource "aws_sns_topic_subscription" "notification" {
  topic_arn = aws_sns_topic.order_events.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.notification.arn
}

resource "aws_lambda_permission" "sns_invoke_notification" {
  statement_id  = "AllowSNSInvokeNotification"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notification.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.order_events.arn
}

# Second independent subscriber on the same topic — demonstrates true fan-out
# (both Lambdas receive every PaymentComplete event, unaware of each other).
resource "aws_sns_topic_subscription" "analytics" {
  topic_arn = aws_sns_topic.order_events.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.analytics.arn
}

resource "aws_lambda_permission" "sns_invoke_analytics" {
  statement_id  = "AllowSNSInvokeAnalytics"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.analytics.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.order_events.arn
}
