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
      Project     = "microservices-platform"
      Environment = var.environment
      ManagedBy   = "Terraform"
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

# EKS Module
module "eks" {
  source = "./modules/eks"
  
  project_name        = var.project_name
  environment         = var.environment
  cluster_version     = var.eks_cluster_version
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  node_instance_types = var.eks_node_instance_types
  node_desired_size   = var.eks_node_desired_size
  node_min_size       = var.eks_node_min_size
  node_max_size       = var.eks_node_max_size
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

# API Gateway Module (for public access)
module "api_gateway" {
  source = "./modules/api-gateway"
  
  project_name        = var.project_name
  environment         = var.environment
  private_alb_dns     = module.private_alb.dns_name
  vpc_link_subnet_ids = module.vpc.private_subnet_ids
}

# Helm Deployments
module "helm_deployments" {
  source = "./modules/helm"
  
  project_name          = var.project_name
  environment           = var.environment
  cluster_name          = module.eks.cluster_name
  ecr_registry_url      = module.ecr.registry_url
  db_endpoint           = module.rds.db_endpoint
  db_username           = var.rds_username
  db_password           = module.rds.db_password
  sns_topic_arn         = module.messaging.sns_topic_arn
  sqs_queue_url         = module.messaging.sqs_queue_url
  s3_bucket_names       = module.s3.bucket_names
  private_alb_arn       = module.private_alb.alb_arn
  private_alb_listener_arn = module.private_alb.listener_arn
  
  depends_on = [module.eks, module.rds, module.ecr, module.messaging]
}
