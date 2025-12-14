# AWS Microservices Platform

A production-ready microservices platform on AWS EKS with Java and Node.js backend services, React frontend, and managed AWS services.

## Architecture Overview

### Services
- **Java Service** (Spring Boot): Order processing microservice
- **Node.js Service** (Express): User management microservice  
- **React Frontend**: Web application UI

### AWS Infrastructure
- **EKS**: Kubernetes cluster for container orchestration
- **RDS**: PostgreSQL database for persistent storage
- **ECR**: Container image registry
- **SNS/SQS**: Messaging and event-driven communication
- **S3**: Static assets and file storage
- **VPC**: Network isolation with public/private subnets
- **ALB**: Application Load Balancer for ingress

## Project Structure

```
.
├── services/
│   ├── java-service/          # Spring Boot microservice
│   └── nodejs-service/        # Express.js microservice
├── frontend/
│   └── react-app/             # React application
├── infrastructure/
│   ├── terraform/             # Terraform IaC
│   └── kubernetes/            # Helm charts
├── .github/
│   └── workflows/             # CI/CD pipelines
└── docs/
    └── architecture.md        # Detailed architecture docs
```

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5
- Docker
- kubectl
- Helm >= 3.0
- Node.js >= 18
- Java >= 17
- Maven >= 3.8

## Quick Start

### 1. Deploy Infrastructure

```bash
cd infrastructure/terraform
terraform init
terraform plan
terraform apply
```

### 2. Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name microservices-cluster
```

### 3. Deploy Applications

Terraform will automatically deploy Helm charts after infrastructure provisioning.

### 4. Build and Push Images

```bash
# Run CI/CD pipeline or manually:
./scripts/build-and-push.sh
```

## CI/CD Pipeline

The GitHub Actions workflow automatically:
1. Builds Docker images for all services
2. Runs tests
3. Pushes images to AWS ECR
4. Deploys to EKS via Helm

## Environment Variables

See `.env.example` files in each service directory.

## Monitoring & Logging

- CloudWatch for logs and metrics
- EKS Console for cluster monitoring
- Application health endpoints: `/health`

## Security

- Private subnets for databases and internal services
- Security groups with least-privilege access
- Secrets managed via AWS Secrets Manager
- IRSA (IAM Roles for Service Accounts) for pod-level permissions

## License

MIT
# microservices
