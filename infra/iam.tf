# Shared trust policy — for every Lambda execution role.
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# --- Order Intake Lambda ---
# Convention: each Lambda gets its own role

resource "aws_iam_role" "order_intake_lambda" {
  name               = "${var.project_name}-${var.environment}-order-intake-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "order_intake_basic_logs" {
  role       = aws_iam_role.order_intake_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "order_intake_permissions" {
  statement {
    sid       = "WriteOrders"
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.orders.arn]
  }

  statement {
    sid       = "PublishToValidationQueue"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.order_validation.arn]
  }
}

resource "aws_iam_role_policy" "order_intake_permissions" {
  name   = "${var.project_name}-${var.environment}-order-intake-permissions"
  role   = aws_iam_role.order_intake_lambda.id
  policy = data.aws_iam_policy_document.order_intake_permissions.json
}

# --- Order Validation Lambda ---

resource "aws_iam_role" "order_validation_lambda" {
  name               = "${var.project_name}-${var.environment}-order-validation-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "order_validation_basic_logs" {
  role       = aws_iam_role.order_validation_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "order_validation_permissions" {
  statement {
    sid       = "ConsumeValidationQueue"
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
    resources = [aws_sqs_queue.order_validation.arn]
  }

  statement {
    sid       = "ForwardToInventoryOrFailures"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.inventory_check.arn, aws_sqs_queue.validation_failures.arn]
  }

  statement {
    sid       = "UpdateOrders"
    actions   = ["dynamodb:UpdateItem"]
    resources = [aws_dynamodb_table.orders.arn]
  }

  statement {
    sid       = "CheckProductExists"
    actions   = ["dynamodb:GetItem"]
    resources = [aws_dynamodb_table.inventory.arn]
  }
}

resource "aws_iam_role_policy" "order_validation_permissions" {
  name   = "${var.project_name}-${var.environment}-order-validation-permissions"
  role   = aws_iam_role.order_validation_lambda.id
  policy = data.aws_iam_policy_document.order_validation_permissions.json
}

# --- Inventory Check Lambda ---

resource "aws_iam_role" "inventory_check_lambda" {
  name               = "${var.project_name}-${var.environment}-inventory-check-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "inventory_check_basic_logs" {
  role       = aws_iam_role.inventory_check_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "inventory_check_permissions" {
  statement {
    sid       = "ConsumeInventoryQueue"
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
    resources = [aws_sqs_queue.inventory_check.arn]
  }

  statement {
    sid       = "ForwardToPaymentOrFailures"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.payment.arn, aws_sqs_queue.inventory_failures.arn]
  }

  statement {
    sid       = "UpdateOrders"
    actions   = ["dynamodb:UpdateItem"]
    resources = [aws_dynamodb_table.orders.arn]
  }

  statement {
    sid       = "ReserveStock"
    actions   = ["dynamodb:UpdateItem"]
    resources = [aws_dynamodb_table.inventory.arn]
  }
}

resource "aws_iam_role_policy" "inventory_check_permissions" {
  name   = "${var.project_name}-${var.environment}-inventory-check-permissions"
  role   = aws_iam_role.inventory_check_lambda.id
  policy = data.aws_iam_policy_document.inventory_check_permissions.json
}

# --- Payment Processing Lambda ---

resource "aws_iam_role" "payment_processing_lambda" {
  name               = "${var.project_name}-${var.environment}-payment-processing-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "payment_processing_basic_logs" {
  role       = aws_iam_role.payment_processing_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "payment_processing_permissions" {
  statement {
    sid       = "ConsumePaymentQueue"
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
    resources = [aws_sqs_queue.payment.arn]
  }

  statement {
    sid       = "SendToPaymentFailures"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.payment_failures.arn]
  }

  statement {
    sid       = "PublishOrderEvents"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.order_events.arn]
  }

  statement {
    sid       = "UpdateOrders"
    actions   = ["dynamodb:UpdateItem"]
    resources = [aws_dynamodb_table.orders.arn]
  }

  statement {
    sid       = "ReleaseReservedStock"
    actions   = ["dynamodb:UpdateItem"]
    resources = [aws_dynamodb_table.inventory.arn]
  }
}

resource "aws_iam_role_policy" "payment_processing_permissions" {
  name   = "${var.project_name}-${var.environment}-payment-processing-permissions"
  role   = aws_iam_role.payment_processing_lambda.id
  policy = data.aws_iam_policy_document.payment_processing_permissions.json
}

# --- Notification Lambda ---

resource "aws_iam_role" "notification_lambda" {
  name               = "${var.project_name}-${var.environment}-notification-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "notification_basic_logs" {
  role       = aws_iam_role.notification_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "notification_permissions" {
  statement {
    sid       = "SendEmail"
    actions   = ["ses:SendEmail", "ses:SendRawEmail"]
    resources = ["*"] # SES send actions don't support resource-level restriction
  }
}

resource "aws_iam_role_policy" "notification_permissions" {
  name   = "${var.project_name}-${var.environment}-notification-permissions"
  role   = aws_iam_role.notification_lambda.id
  policy = data.aws_iam_policy_document.notification_permissions.json
}

# --- Analytics Lambda ---
# Logs-only

resource "aws_iam_role" "analytics_lambda" {
  name               = "${var.project_name}-${var.environment}-analytics-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "analytics_basic_logs" {
  role       = aws_iam_role.analytics_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
