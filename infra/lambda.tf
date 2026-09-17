data "archive_file" "order_intake" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/order-intake"
  output_path = "${path.module}/build/order-intake.zip"
  excludes    = ["tests"]
}

resource "aws_lambda_function" "order_intake" {
  function_name    = "${var.project_name}-${var.environment}-order-intake"
  role              = aws_iam_role.order_intake_lambda.arn
  handler           = "handler.lambda_handler"
  runtime           = "python3.12"
  timeout           = 10
  filename          = data.archive_file.order_intake.output_path
  source_code_hash  = data.archive_file.order_intake.output_base64sha256

  environment {
    variables = {
      ORDERS_TABLE_NAME    = aws_dynamodb_table.orders.name
      VALIDATION_QUEUE_URL = aws_sqs_queue.order_validation.url
    }
  }
}

# --- Order Validation Lambda ---

data "archive_file" "order_validation" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/order-validation"
  output_path = "${path.module}/build/order-validation.zip"
  excludes    = ["tests"]
}

resource "aws_lambda_function" "order_validation" {
  function_name    = "${var.project_name}-${var.environment}-order-validation"
  role              = aws_iam_role.order_validation_lambda.arn
  handler           = "handler.lambda_handler"
  runtime           = "python3.12"
  timeout           = 10
  filename          = data.archive_file.order_validation.output_path
  source_code_hash  = data.archive_file.order_validation.output_base64sha256

  environment {
    variables = {
      ORDERS_TABLE_NAME             = aws_dynamodb_table.orders.name
      INVENTORY_TABLE_NAME          = aws_dynamodb_table.inventory.name
      INVENTORY_QUEUE_URL           = aws_sqs_queue.inventory_check.url
      VALIDATION_FAILURES_QUEUE_URL = aws_sqs_queue.validation_failures.url
    }
  }
}

resource "aws_lambda_event_source_mapping" "order_validation_trigger" {
  event_source_arn = aws_sqs_queue.order_validation.arn
  function_name    = aws_lambda_function.order_validation.arn
  batch_size       = 1
}

# --- Inventory Check Lambda ---

data "archive_file" "inventory_check" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/inventory-check"
  output_path = "${path.module}/build/inventory-check.zip"
  excludes    = ["tests"]
}

resource "aws_lambda_function" "inventory_check" {
  function_name    = "${var.project_name}-${var.environment}-inventory-check"
  role              = aws_iam_role.inventory_check_lambda.arn
  handler           = "handler.lambda_handler"
  runtime           = "python3.12"
  timeout           = 10
  filename          = data.archive_file.inventory_check.output_path
  source_code_hash  = data.archive_file.inventory_check.output_base64sha256

  environment {
    variables = {
      ORDERS_TABLE_NAME            = aws_dynamodb_table.orders.name
      INVENTORY_TABLE_NAME         = aws_dynamodb_table.inventory.name
      PAYMENT_QUEUE_URL            = aws_sqs_queue.payment.url
      INVENTORY_FAILURES_QUEUE_URL = aws_sqs_queue.inventory_failures.url
    }
  }
}

resource "aws_lambda_event_source_mapping" "inventory_check_trigger" {
  event_source_arn = aws_sqs_queue.inventory_check.arn
  function_name    = aws_lambda_function.inventory_check.arn
  batch_size       = 1
}

# --- Payment Processing Lambda ---

data "archive_file" "payment_processing" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/payment-processing"
  output_path = "${path.module}/build/payment-processing.zip"
  excludes    = ["tests"]
}

resource "aws_lambda_function" "payment_processing" {
  function_name    = "${var.project_name}-${var.environment}-payment-processing"
  role              = aws_iam_role.payment_processing_lambda.arn
  handler           = "handler.lambda_handler"
  runtime           = "python3.12"
  timeout           = 10
  filename          = data.archive_file.payment_processing.output_path
  source_code_hash  = data.archive_file.payment_processing.output_base64sha256

  environment {
    variables = {
      ORDERS_TABLE_NAME          = aws_dynamodb_table.orders.name
      INVENTORY_TABLE_NAME       = aws_dynamodb_table.inventory.name
      ORDER_EVENTS_TOPIC_ARN     = aws_sns_topic.order_events.arn
      PAYMENT_FAILURES_QUEUE_URL = aws_sqs_queue.payment_failures.url
      PAYMENT_SUCCESS_RATE       = "0.8"
    }
  }
}

resource "aws_lambda_event_source_mapping" "payment_processing_trigger" {
  event_source_arn = aws_sqs_queue.payment.arn
  function_name    = aws_lambda_function.payment_processing.arn
  batch_size       = 1
}

# --- Notification Lambda ---
# Invoked by SNS (see sns.tf), not an SQS event source mapping.

data "archive_file" "notification" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/notification"
  output_path = "${path.module}/build/notification.zip"
  excludes    = ["tests"]
}

resource "aws_lambda_function" "notification" {
  function_name    = "${var.project_name}-${var.environment}-notification"
  role              = aws_iam_role.notification_lambda.arn
  handler           = "handler.lambda_handler"
  runtime           = "python3.12"
  timeout           = 10
  filename          = data.archive_file.notification.output_path
  source_code_hash  = data.archive_file.notification.output_base64sha256

  environment {
    variables = {
      SES_SENDER_EMAIL = var.ses_sender_email
    }
  }
}

# --- Analytics Lambda (stretch) ---
# Also invoked by SNS — second independent subscriber on the same topic.

data "archive_file" "analytics" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/analytics"
  output_path = "${path.module}/build/analytics.zip"
  excludes    = ["tests"]
}

resource "aws_lambda_function" "analytics" {
  function_name    = "${var.project_name}-${var.environment}-analytics"
  role              = aws_iam_role.analytics_lambda.arn
  handler           = "handler.lambda_handler"
  runtime           = "python3.12"
  timeout           = 10
  filename          = data.archive_file.analytics.output_path
  source_code_hash  = data.archive_file.analytics.output_base64sha256
}
