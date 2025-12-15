# SNS Topic for Cost Alerts
resource "aws_sns_topic" "cost_alerts" {
  name = "${var.project_name}-${var.environment}-cost-alerts"

  tags = {
    Name = "${var.project_name}-${var.environment}-cost-alerts"
  }
}

resource "aws_sns_topic_subscription" "cost_alerts_email" {
  count     = length(var.alert_emails)
  topic_arn = aws_sns_topic.cost_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_emails[count.index]
}

# AWS Budget - Monthly Cost Budget
resource "aws_budgets_budget" "monthly_cost" {
  name         = "${var.project_name}-${var.environment}-monthly-cost"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name = "TagKeyValue"
    values = [
      "user:Project$${var.project_name}",
      "user:Environment$${var.environment}"
    ]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 90
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.alert_emails
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-monthly-cost"
  }
}

# AWS Budget - EKS Specific Budget
resource "aws_budgets_budget" "eks_cost" {
  name         = "${var.project_name}-${var.environment}-eks-cost"
  budget_type  = "COST"
  limit_amount = var.eks_monthly_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name = "Service"
    values = [
      "Amazon Elastic Kubernetes Service",
      "Amazon EC2 Container Service"
    ]
  }

  cost_filter {
    name = "TagKeyValue"
    values = [
      "user:Environment$${var.environment}"
    ]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-cost"
  }
}

# AWS Budget - RDS Specific Budget
resource "aws_budgets_budget" "rds_cost" {
  name         = "${var.project_name}-${var.environment}-rds-cost"
  budget_type  = "COST"
  limit_amount = var.rds_monthly_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name = "Service"
    values = [
      "Amazon Relational Database Service"
    ]
  }

  cost_filter {
    name = "TagKeyValue"
    values = [
      "user:Environment$${var.environment}"
    ]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-cost"
  }
}

# CloudWatch Billing Alarms
resource "aws_cloudwatch_metric_alarm" "estimated_charges" {
  alarm_name          = "${var.project_name}-${var.environment}-estimated-charges"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 21600 # 6 hours
  statistic           = "Maximum"
  threshold           = var.monthly_budget_limit * 0.8
  alarm_description   = "Alert when estimated charges exceed 80% of budget"
  alarm_actions       = [aws_sns_topic.cost_alerts.arn]

  dimensions = {
    Currency = "USD"
  }
}

# Cost Anomaly Detection
resource "aws_ce_anomaly_monitor" "service_monitor" {
  name              = "${var.project_name}-${var.environment}-service-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"

  tags = {
    Name = "${var.project_name}-${var.environment}-service-monitor"
  }
}

resource "aws_ce_anomaly_subscription" "anomaly_alerts" {
  name      = "${var.project_name}-${var.environment}-anomaly-alerts"
  frequency = "DAILY"

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      values        = ["100"]
      match_options = ["GREATER_THAN_OR_EQUAL"]
    }
  }

  monitor_arn_list = [
    aws_ce_anomaly_monitor.service_monitor.arn
  ]

  subscriber {
    type    = "SNS"
    address = aws_sns_topic.cost_alerts.arn
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-anomaly-alerts"
  }
}

# Cost Allocation Tags (enable via AWS Cost Explorer API)
resource "null_resource" "activate_cost_tags" {
  provisioner "local-exec" {
    command = <<-EOT
      aws ce create-cost-category-definition \
        --name "${var.project_name}-${var.environment}-cost-category" \
        --rules '[
          {
            "Value": "EKS",
            "Rule": {
              "Tags": {
                "Key": "Service",
                "Values": ["eks"]
              }
            }
          },
          {
            "Value": "RDS", 
            "Rule": {
              "Tags": {
                "Key": "Service",
                "Values": ["rds"]
              }
            }
          }
        ]' \
        --rule-version "CostCategoryExpression.v1" || true
    EOT
  }

  triggers = {
    always_run = timestamp()
  }
}

# Savings Plan Recommendations (for visibility)
data "aws_ce_cost_category" "environment_category" {
  cost_category_arn = "arn:aws:ce::${data.aws_caller_identity.current.account_id}:costcategory/${var.project_name}"
}

data "aws_caller_identity" "current" {}
