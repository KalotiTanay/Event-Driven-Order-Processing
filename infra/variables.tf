########################################
# EDOS - variables.tf
# Shared input variables for the whole project.
# Component-specific variables (Lambda names, queue names, etc.) will be
# added to this file as later components are built, or split into their
# own files if it grows too large.
########################################

variable "aws_region" {
  description = "AWS region to deploy all resources into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short project identifier used as a prefix for resource names and tags"
  type        = string
  default     = "edos"
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod). Portfolio projects typically just use 'dev'."
  type        = string
  default     = "dev"
}

variable "ses_sender_email" {
  description = "Verified SES sender address for order confirmation emails. Leave empty to log a simulated notification instead (avoids SES sandbox restrictions for MVP demos)."
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Optional email address to subscribe to ops alerts (DLQ depth alarms). Leave empty to skip the subscription."
  type        = string
  default     = ""
}

# ------------------------------------------------------------------
# Naming convention (documented here for reference, enforced by
# convention in each resource block): 
#   {project_name}-{environment}-{resource-description}
#   e.g. edos-dev-orders-table, edos-dev-order-intake-lambda
# ------------------------------------------------------------------
