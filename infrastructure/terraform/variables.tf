variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "microservices-platform"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "eks_cluster_version" {
  description = "EKS cluster version (minimum 1.31 for Auto Mode)"
  type        = string
  default     = "1.31"
}

variable "enable_eks_auto_mode" {
  description = "Enable EKS Auto Mode for automated node provisioning"
  type        = bool
  default     = false
}

variable "eks_auto_mode_node_pools" {
  description = "Node pools for EKS Auto Mode"
  type        = list(string)
  default     = ["general-purpose"]
}

variable "eks_node_instance_types" {
  description = "EKS node instance types"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_desired_size" {
  description = "Desired number of EKS nodes"
  type        = number
  default     = 3
}

variable "eks_node_min_size" {
  description = "Minimum number of EKS nodes"
  type        = number
  default     = 2
}

variable "eks_node_max_size" {
  description = "Maximum number of EKS nodes"
  type        = number
  default     = 5
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "rds_username" {
  description = "RDS master username"
  type        = string
  default     = "dbadmin"
  sensitive   = true
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for ALB HTTPS"
  type        = string
  default     = ""
}

# Well-Architected Framework Variables
variable "alert_emails" {
  description = "List of email addresses for alerts and notifications"
  type        = list(string)
  default     = []
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD for cost optimization"
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

# API Gateway Configuration
variable "api_throttle_burst_limit" {
  description = "API Gateway throttle burst limit"
  type        = number
  default     = 5000
}

variable "api_throttle_rate_limit" {
  description = "API Gateway throttle rate limit (requests per second)"
  type        = number
  default     = 2000
}

variable "api_waf_rate_limit" {
  description = "WAF rate limit per 5 minutes per IP"
  type        = number
  default     = 2000
}

variable "api_cors_allow_origins" {
  description = "CORS allowed origins for API Gateway"
  type        = list(string)
  default     = ["*"]
}

variable "api_allowed_countries" {
  description = "List of allowed country codes (ISO 3166-1 alpha-2). Empty = no restriction"
  type        = list(string)
  default     = []
}

variable "api_custom_domain_name" {
  description = "Custom domain name for API Gateway"
  type        = string
  default     = ""
}
