output "eks_kms_key_id" {
  description = "KMS key ID for EKS secrets encryption"
  value       = aws_kms_key.eks.id
}

output "eks_kms_key_arn" {
  description = "KMS key ARN for EKS secrets encryption"
  value       = aws_kms_key.eks.arn
}

output "rds_kms_key_id" {
  description = "KMS key ID for RDS encryption"
  value       = aws_kms_key.rds.id
}

output "rds_kms_key_arn" {
  description = "KMS key ARN for RDS encryption"
  value       = aws_kms_key.rds.arn
}

output "s3_kms_key_id" {
  description = "KMS key ID for S3 encryption"
  value       = aws_kms_key.s3.id
}

output "s3_kms_key_arn" {
  description = "KMS key ARN for S3 encryption"
  value       = aws_kms_key.s3.arn
}

output "ebs_kms_key_id" {
  description = "KMS key ID for EBS encryption"
  value       = aws_kms_key.ebs.id
}

output "ebs_kms_key_arn" {
  description = "KMS key ARN for EBS encryption"
  value       = aws_kms_key.ebs.arn
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = aws_guardduty_detector.main.id
}

output "config_bucket_name" {
  description = "S3 bucket name for AWS Config"
  value       = aws_s3_bucket.config.id
}

output "flow_logs_bucket_name" {
  description = "S3 bucket name for VPC Flow Logs"
  value       = aws_s3_bucket.flow_logs.id
}

output "db_credentials_secret_arn" {
  description = "Secrets Manager ARN for database credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}
