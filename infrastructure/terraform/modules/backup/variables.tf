variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for backup encryption"
  type        = string
}

variable "rds_arns" {
  description = "List of RDS ARNs to back up"
  type        = list(string)
  default     = []
}

variable "notification_emails" {
  description = "List of email addresses for backup notifications"
  type        = list(string)
  default     = []
}

variable "enable_cross_region_backup" {
  description = "Enable cross-region backup replication"
  type        = bool
  default     = false
}

variable "cross_region_kms_key_arn" {
  description = "KMS key ARN in backup region"
  type        = string
  default     = ""
}
