output "backup_vault_arn" {
  description = "ARN of the backup vault"
  value       = aws_backup_vault.main.arn
}

output "backup_vault_name" {
  description = "Name of the backup vault"
  value       = aws_backup_vault.main.name
}

output "rds_daily_plan_id" {
  description = "ID of RDS daily backup plan"
  value       = aws_backup_plan.rds_daily.id
}

output "rds_weekly_plan_id" {
  description = "ID of RDS weekly backup plan"
  value       = aws_backup_plan.rds_weekly.id
}

output "ebs_plan_id" {
  description = "ID of EBS backup plan"
  value       = aws_backup_plan.ebs.id
}

output "backup_notifications_topic_arn" {
  description = "SNS topic ARN for backup notifications"
  value       = aws_sns_topic.backup_notifications.arn
}
