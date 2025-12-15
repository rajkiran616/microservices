variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "cluster_version" {
  description = "EKS cluster version (minimum 1.31 for Auto Mode)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS"
  type        = list(string)
}

variable "secrets_kms_key_arn" {
  description = "KMS key ARN for EKS secrets encryption"
  type        = string
}

# Auto Mode Configuration
variable "enable_auto_mode" {
  description = "Enable EKS Auto Mode for automated node provisioning"
  type        = bool
  default     = false
}

variable "auto_mode_node_pools" {
  description = "Node pools for EKS Auto Mode (e.g., ['general-purpose', 'system'])"
  type        = list(string)
  default     = ["general-purpose"]
}

# Traditional Node Group Configuration (used when Auto Mode is disabled)
variable "node_instance_types" {
  description = "Instance types for traditional node groups"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of nodes (traditional mode only)"
  type        = number
  default     = 3
}

variable "node_min_size" {
  description = "Minimum number of nodes (traditional mode only)"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of nodes (traditional mode only)"
  type        = number
  default     = 5
}
