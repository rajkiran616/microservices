output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.db_endpoint
}

output "ecr_repositories" {
  description = "ECR repository URLs"
  value       = module.ecr.repository_urls
}

output "sns_topic_arn" {
  description = "SNS topic ARN"
  value       = module.messaging.sns_topic_arn
}

output "sqs_queue_url" {
  description = "SQS queue URL"
  value       = module.messaging.sqs_queue_url
}

output "s3_buckets" {
  description = "S3 bucket names"
  value       = module.s3.bucket_names
}

output "private_alb_dns" {
  description = "Private ALB DNS name (for VPN access)"
  value       = module.private_alb.dns_name
}

# API Gateway Outputs
output "api_gateway_endpoint" {
  description = "API Gateway public endpoint URL"
  value       = module.api_gateway.api_endpoint
}

output "api_gateway_custom_domain" {
  description = "API Gateway custom domain (if configured)"
  value       = module.api_gateway.custom_domain_name
}

output "api_gateway_waf_web_acl_arn" {
  description = "WAF Web ACL ARN protecting API Gateway"
  value       = module.api_gateway.waf_web_acl_arn
}

output "api_health_check_url" {
  description = "API Gateway health check URL"
  value       = "${module.api_gateway.api_endpoint}/health"
}

# EKS Auto Mode
output "eks_auto_mode_enabled" {
  description = "Whether EKS Auto Mode is enabled"
  value       = module.eks.auto_mode_enabled
}

# Security Outputs
output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = module.security.guardduty_detector_id
}

output "kms_eks_key_arn" {
  description = "KMS key ARN for EKS secrets encryption"
  value       = module.security.eks_kms_key_arn
}

# Observability Outputs
output "observability_sns_topic_arn" {
  description = "SNS topic ARN for operational alerts"
  value       = module.observability.sns_topic_arn
}

output "container_insights_log_group" {
  description = "CloudWatch log group for container insights"
  value       = module.observability.container_insights_log_group
}

# Backup Outputs
output "backup_vault_name" {
  description = "AWS Backup vault name"
  value       = module.backup.backup_vault_name
}

# Cost Optimization Outputs
output "cost_alerts_topic_arn" {
  description = "SNS topic ARN for cost alerts"
  value       = module.cost_optimization.cost_alerts_topic_arn
}

output "monthly_budget_name" {
  description = "Name of monthly cost budget"
  value       = module.cost_optimization.monthly_budget_name
}

output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
