# AWS Backup Vault
resource "aws_backup_vault" "main" {
  name        = "${var.project_name}-${var.environment}-backup-vault"
  kms_key_arn = var.kms_key_arn

  tags = {
    Name = "${var.project_name}-${var.environment}-backup-vault"
  }
}

# AWS Backup Vault for Cross-Region Replication
resource "aws_backup_vault" "cross_region" {
  count       = var.enable_cross_region_backup ? 1 : 0
  provider    = aws.backup_region
  name        = "${var.project_name}-${var.environment}-backup-vault-replica"
  kms_key_arn = var.cross_region_kms_key_arn

  tags = {
    Name = "${var.project_name}-${var.environment}-backup-vault-replica"
  }
}

# IAM Role for AWS Backup
resource "aws_iam_role" "backup" {
  name = "${var.project_name}-${var.environment}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "backup.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-backup-role"
  }
}

resource "aws_iam_role_policy_attachment" "backup_service" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restore" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# Backup Plan for RDS - Daily
resource "aws_backup_plan" "rds_daily" {
  name = "${var.project_name}-${var.environment}-rds-daily"

  rule {
    rule_name         = "daily_backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 3 * * ? *)" # 3 AM UTC daily

    lifecycle {
      delete_after = var.environment == "prod" ? 90 : 30
    }

    dynamic "copy_action" {
      for_each = var.enable_cross_region_backup ? [1] : []
      content {
        destination_vault_arn = aws_backup_vault.cross_region[0].arn
        lifecycle {
          delete_after = var.environment == "prod" ? 90 : 30
        }
      }
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-daily"
  }
}

# Backup Plan for RDS - Weekly (long-term retention)
resource "aws_backup_plan" "rds_weekly" {
  name = "${var.project_name}-${var.environment}-rds-weekly"

  rule {
    rule_name         = "weekly_backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 4 ? * SUN *)" # 4 AM UTC on Sundays

    lifecycle {
      cold_storage_after = 30
      delete_after       = var.environment == "prod" ? 365 : 90
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-weekly"
  }
}

# Backup Plan for EBS Volumes
resource "aws_backup_plan" "ebs" {
  name = "${var.project_name}-${var.environment}-ebs"

  rule {
    rule_name         = "daily_ebs_backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 2 * * ? *)" # 2 AM UTC daily

    lifecycle {
      delete_after = 30
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ebs"
  }
}

# Backup Selection for RDS Daily
resource "aws_backup_selection" "rds_daily" {
  name         = "${var.project_name}-${var.environment}-rds-daily-selection"
  plan_id      = aws_backup_plan.rds_daily.id
  iam_role_arn = aws_iam_role.backup.arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "BackupPlan"
    value = "daily"
  }

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Environment"
    value = var.environment
  }

  resources = var.rds_arns
}

# Backup Selection for RDS Weekly
resource "aws_backup_selection" "rds_weekly" {
  name         = "${var.project_name}-${var.environment}-rds-weekly-selection"
  plan_id      = aws_backup_plan.rds_weekly.id
  iam_role_arn = aws_iam_role.backup.arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "BackupPlan"
    value = "weekly"
  }

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Environment"
    value = var.environment
  }

  resources = var.rds_arns
}

# Backup Selection for EBS
resource "aws_backup_selection" "ebs" {
  name         = "${var.project_name}-${var.environment}-ebs-selection"
  plan_id      = aws_backup_plan.ebs.id
  iam_role_arn = aws_iam_role.backup.arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "BackupPlan"
    value = "ebs"
  }

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Environment"
    value = var.environment
  }
}

# SNS Topic for Backup Notifications
resource "aws_sns_topic" "backup_notifications" {
  name = "${var.project_name}-${var.environment}-backup-notifications"

  tags = {
    Name = "${var.project_name}-${var.environment}-backup-notifications"
  }
}

resource "aws_sns_topic_subscription" "backup_notifications_email" {
  count     = length(var.notification_emails)
  topic_arn = aws_sns_topic.backup_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_emails[count.index]
}

# AWS Backup Vault Notifications
resource "aws_backup_vault_notifications" "main" {
  backup_vault_name   = aws_backup_vault.main.name
  sns_topic_arn       = aws_sns_topic.backup_notifications.arn
  backup_vault_events = ["BACKUP_JOB_STARTED", "BACKUP_JOB_COMPLETED", "BACKUP_JOB_FAILED", "RESTORE_JOB_COMPLETED", "RESTORE_JOB_FAILED"]
}

# CloudWatch Alarms for Backup Jobs
resource "aws_cloudwatch_metric_alarm" "backup_job_failed" {
  alarm_name          = "${var.project_name}-${var.environment}-backup-job-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "NumberOfBackupJobsFailed"
  namespace           = "AWS/Backup"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when backup jobs fail"
  alarm_actions       = [aws_sns_topic.backup_notifications.arn]
}

resource "aws_cloudwatch_metric_alarm" "restore_job_failed" {
  alarm_name          = "${var.project_name}-${var.environment}-restore-job-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "NumberOfRestoreJobsFailed"
  namespace           = "AWS/Backup"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when restore jobs fail"
  alarm_actions       = [aws_sns_topic.backup_notifications.arn]
}
