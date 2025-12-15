variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for VPC Flow Logs"
  type        = string
  default     = ""
}

variable "db_username" {
  description = "Database username for Secrets Manager"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database password for Secrets Manager"
  type        = string
  sensitive   = true
}
