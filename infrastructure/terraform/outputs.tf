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

output "api_gateway_url" {
  description = "API Gateway URL (public access)"
  value       = module.api_gateway.api_url
}

output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
