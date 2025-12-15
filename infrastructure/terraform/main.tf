terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "microservices-platform/terraform.tfstate"
    region = "us-east-1"
    # encrypt = true
    # dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      CostCenter  = "Engineering"
      Owner       = "DevOps"
    }
  }
}

# Data source for EKS cluster auth
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
  depends_on = [module.eks]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  azs          = var.availability_zones
}

# Security Module (must be created before EKS for KMS keys)
module "security" {
  source = "./modules/security"
  
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
  vpc_id       = module.vpc.vpc_id
  db_username  = var.rds_username
  db_password  = random_password.db_password.result
}

# EKS Module
module "eks" {
  source = "./modules/eks"
  
  project_name        = var.project_name
  environment         = var.environment
  cluster_version     = var.eks_cluster_version
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  secrets_kms_key_arn = module.security.eks_kms_key_arn
  
  # Auto Mode Configuration
  enable_auto_mode      = var.enable_eks_auto_mode
  auto_mode_node_pools  = var.eks_auto_mode_node_pools
  
  # Traditional Node Group Configuration (used when Auto Mode is disabled)
  node_instance_types = var.eks_node_instance_types
  node_desired_size   = var.eks_node_desired_size
  node_min_size       = var.eks_node_min_size
  node_max_size       = var.eks_node_max_size
  
  depends_on = [module.security]
}

# RDS Module
module "rds" {
  source = "./modules/rds"
  
  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  db_instance_class  = var.rds_instance_class
  db_username        = var.rds_username
  eks_security_group_id = module.eks.cluster_security_group_id
}

# ECR Module
module "ecr" {
  source = "./modules/ecr"
  
  project_name = var.project_name
  environment  = var.environment
  repositories = ["java-service", "nodejs-service", "react-app"]
}

# SNS/SQS Module
module "messaging" {
  source = "./modules/messaging"
  
  project_name = var.project_name
  environment  = var.environment
}

# S3 Module
module "s3" {
  source = "./modules/s3"
  
  project_name = var.project_name
  environment  = var.environment
}

# Private ALB Module (for internal/VPN access)
module "private_alb" {
  source = "./modules/alb"
  
  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  internal           = true
  certificate_arn    = var.acm_certificate_arn
}

# API Gateway Module (for public access with WAF)
module "api_gateway" {
  source = "./modules/api-gateway"
  
  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  alb_listener_arn    = module.private_alb.listener_arn
  
  # Logging and monitoring
  log_retention_days = var.environment == "prod" ? 90 : 30
  alarm_topic_arns   = [module.observability.sns_topic_arn]
  
  # Throttling configuration
  throttle_burst_limit = var.api_throttle_burst_limit
  throttle_rate_limit  = var.api_throttle_rate_limit
  waf_rate_limit       = var.api_waf_rate_limit
  
  # CORS configuration (customize for your frontend)
  cors_allow_origins = var.api_cors_allow_origins
  cors_allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"]
  cors_allow_headers = ["content-type", "authorization", "x-request-id", "x-api-key"]
  
  # Optional: Geographic restrictions
  allowed_countries = var.api_allowed_countries
  
  # Optional: Custom domain
  custom_domain_name  = var.api_custom_domain_name
  acm_certificate_arn = var.acm_certificate_arn
  
  depends_on = [module.private_alb, module.observability]
}

# Observability Module
module "observability" {
  source = "./modules/observability"
  
  project_name       = var.project_name
  environment        = var.environment
  cluster_name       = module.eks.cluster_name
  log_retention_days = var.environment == "prod" ? 90 : 30
  alert_emails       = var.alert_emails
  rds_instance_id    = module.rds.db_instance_id
  alb_arn_suffix     = module.private_alb.alb_arn_suffix
  
  depends_on = [module.eks]
}

# Backup Module
module "backup" {
  source = "./modules/backup"
  
  project_name               = var.project_name
  environment                = var.environment
  kms_key_arn                = module.security.rds_kms_key_arn
  rds_arns                   = [module.rds.db_arn]
  notification_emails        = var.alert_emails
  enable_cross_region_backup = var.environment == "prod" ? true : false
  
  depends_on = [module.rds, module.security]
}

# Cost Optimization Module
module "cost_optimization" {
  source = "./modules/cost-optimization"
  
  project_name            = var.project_name
  environment             = var.environment
  monthly_budget_limit    = var.monthly_budget_limit
  eks_monthly_budget_limit = var.eks_monthly_budget_limit
  rds_monthly_budget_limit = var.rds_monthly_budget_limit
  alert_emails            = var.alert_emails
}

# Helm Deployments
module "helm_deployments" {
  source = "./modules/helm"
  
  project_name             = var.project_name
  environment              = var.environment
  cluster_name             = module.eks.cluster_name
  ecr_registry_url         = module.ecr.registry_url
  db_endpoint              = module.rds.db_endpoint
  db_username              = var.rds_username
  db_password              = module.rds.db_password
  sns_topic_arn            = module.messaging.sns_topic_arn
  sqs_queue_url            = module.messaging.sqs_queue_url
  s3_bucket_names          = module.s3.bucket_names
  private_alb_arn          = module.private_alb.alb_arn
  private_alb_listener_arn = module.private_alb.listener_arn
  
  depends_on = [module.eks, module.rds, module.ecr, module.messaging, module.observability]
}

# Random password for database
resource "random_password" "db_password" {
  length  = 32
  special = true
}
