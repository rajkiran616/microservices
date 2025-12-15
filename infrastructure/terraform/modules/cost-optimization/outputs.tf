output "cost_alerts_topic_arn" {
  description = "SNS topic ARN for cost alerts"
  value       = aws_sns_topic.cost_alerts.arn
}

output "monthly_budget_name" {
  description = "Name of monthly cost budget"
  value       = aws_budgets_budget.monthly_cost.name
}

output "eks_budget_name" {
  description = "Name of EKS cost budget"
  value       = aws_budgets_budget.eks_cost.name
}

output "rds_budget_name" {
  description = "Name of RDS cost budget"
  value       = aws_budgets_budget.rds_cost.name
}

output "anomaly_monitor_arn" {
  description = "ARN of cost anomaly monitor"
  value       = aws_ce_anomaly_monitor.service_monitor.arn
}
