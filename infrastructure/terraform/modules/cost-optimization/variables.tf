variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = number
  default     = 1000
}

variable "eks_monthly_budget_limit" {
  description = "Monthly EKS budget limit in USD"
  type        = number
  default     = 400
}

variable "rds_monthly_budget_limit" {
  description = "Monthly RDS budget limit in USD"
  type        = number
  default     = 300
}

variable "alert_emails" {
  description = "List of email addresses for cost alerts"
  type        = list(string)
  default     = []
}
