resource "aws_sns_topic" "ops_alerts" {
  name = "${var.project_name}-${var.environment}-ops-alerts"
}

resource "aws_sns_topic_subscription" "ops_alerts_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.ops_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# --- DLQ depth alarms ---
# Any message landing in a DLQ means a terminal failure happened somewhere
# upstream — alarm on presence, not a high-water threshold.

locals {
  dlqs = {
    validation-failures = aws_sqs_queue.validation_failures.name
    inventory-failures  = aws_sqs_queue.inventory_failures.name
    payment-failures    = aws_sqs_queue.payment_failures.name
  }
}

resource "aws_cloudwatch_metric_alarm" "dlq_depth" {
  for_each            = local.dlqs
  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-depth"
  alarm_description   = "Triggers when a message lands in ${each.key} — inspect and replay from the queue."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_actions       = [aws_sns_topic.ops_alerts.arn]

  dimensions = {
    QueueName = each.value
  }
}

# --- Pipeline dashboard ---

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-pipeline"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Invocations & Errors"
          region = var.aws_region
          period = 60
          stat   = "Sum"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.order_intake.function_name],
            ["...", "Errors", "FunctionName", aws_lambda_function.order_intake.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.order_validation.function_name],
            ["...", "Errors", "FunctionName", aws_lambda_function.order_validation.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.inventory_check.function_name],
            ["...", "Errors", "FunctionName", aws_lambda_function.inventory_check.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.payment_processing.function_name],
            ["...", "Errors", "FunctionName", aws_lambda_function.payment_processing.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.notification.function_name],
            ["...", "Errors", "FunctionName", aws_lambda_function.notification.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.analytics.function_name],
            ["...", "Errors", "FunctionName", aws_lambda_function.analytics.function_name],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "SQS Queue Depth"
          region = var.aws_region
          period = 60
          stat   = "Maximum"
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.order_validation.name],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.inventory_check.name],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.payment.name],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Duration (avg, ms)"
          region = var.aws_region
          period = 60
          stat   = "Average"
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.order_intake.function_name],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.order_validation.function_name],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.inventory_check.function_name],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.payment_processing.function_name],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.notification.function_name],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Dead-Letter Queue Depth"
          region = var.aws_region
          period = 60
          stat   = "Maximum"
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.validation_failures.name],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.inventory_failures.name],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.payment_failures.name],
          ]
        }
      }
    ]
  })
}
