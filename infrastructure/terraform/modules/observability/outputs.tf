output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "container_insights_log_group" {
  description = "CloudWatch log group for container insights"
  value       = aws_cloudwatch_log_group.container_insights.name
}

output "performance_log_group" {
  description = "CloudWatch log group for performance logs"
  value       = aws_cloudwatch_log_group.performance.name
}
