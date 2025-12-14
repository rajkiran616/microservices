# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This is a production-ready AWS microservices platform with:
- **Java Service** (Spring Boot): Order processing at `services/java-service/`
- **Node.js Service** (Express): User management at `services/nodejs-service/`
- **React Frontend**: Web UI at `frontend/react-app/`
- **Infrastructure as Code**: Terraform modules at `infrastructure/terraform/`

## Essential Commands

### Local Development (Docker Compose)

```bash
# Start all services with LocalStack (AWS mock)
make start
# or: docker-compose up -d

# View logs
make logs

# Stop services
make stop

# Clean rebuild
make clean && make build && make start
```

Services will be available at:
- Frontend: http://localhost:3001
- Java service: http://localhost:8080 (health: /actuator/health)
- Node.js service: http://localhost:3000 (health: /health)
- PostgreSQL: localhost:5432
- LocalStack (AWS services): localhost:4566

### Service-Specific Development

```bash
# Java service (Spring Boot)
cd services/java-service
mvn spring-boot:run          # Run locally
mvn test                     # Run tests
mvn clean package            # Build JAR

# Node.js service (Express)
cd services/nodejs-service
npm run dev                  # Run with hot reload
npm test                     # Run tests

# React frontend
cd frontend/react-app
npm start                    # Development server
npm test                     # Run tests
npm run build                # Production build
```

### AWS Infrastructure

```bash
# Deploy infrastructure to AWS
make deploy-infra
# or: cd infrastructure/terraform && terraform init && terraform plan && terraform apply

# Configure kubectl for EKS
make kubectl-config
# or: aws eks update-kubeconfig --region us-east-1 --name microservices-platform-dev

# Destroy infrastructure
make destroy-infra

# Login to ECR (requires ECR_REGISTRY env var)
make ecr-login
```

### Testing Message Flow

```bash
# Create an order (Java service publishes to SNS)
curl -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{"userId": 1, "productName": "Laptop", "quantity": 1, "totalAmount": 999.99}'

# Node.js service will consume the message from SQS queue
docker-compose logs -f nodejs-service
```

## Architecture

### Service Communication Pattern

1. **Synchronous**: Frontend → ALB → Backend services (REST APIs)
2. **Asynchronous**: Java service → SNS → SQS → Node.js service
3. **Database**: Each service has its own PostgreSQL database (orderdb, userdb)
4. **Storage**: Both services use S3 for file storage

### Key Architecture Components

- **VPC**: Public subnets (ALB, frontend) + Private subnets (services, RDS)
- **EKS**: Kubernetes cluster running all application pods
- **RDS**: PostgreSQL in private subnet with Multi-AZ
- **SNS/SQS**: Event-driven communication between services
- **LocalStack**: Used in docker-compose for local AWS service emulation
- **Terraform Modules**: vpc, eks, rds, ecr, messaging, s3, alb, api-gateway, helm

### Java Service Structure

Package: `com.example.orderservice`
- **Controller**: REST endpoints (`OrderController`)
- **Service**: Business logic
- **Repository**: Spring Data JPA (`OrderRepository`)
- **Model**: JPA entities (`Order`)
- **Config**: AWS SDK configuration (`AwsConfig`)
- Uses Spring Boot Actuator for `/actuator/health` endpoint
- Publishes to SNS topic `order-events` when orders are created

### Node.js Service Structure

- **Routes**: Express route definitions (`src/routes/userRoutes.js`)
- **Controllers**: Request handlers (`src/controllers/userController.js`)
- **Models**: Database models (`src/models/userModel.js`)
- **Services**: SQS consumer (`src/services/sqsConsumer.js`)
- **Config**: Database and AWS configuration (`src/config/`)
- Subscribes to SQS queue `order-notifications`

### Terraform Module Dependencies

Main modules in `infrastructure/terraform/modules/`:
- **vpc**: Creates VPC, subnets, NAT gateways
- **eks**: EKS cluster, node groups, IRSA roles
- **rds**: RDS Aurora/PostgreSQL instance
- **ecr**: Container registries for java-service, nodejs-service, react-app
- **messaging**: SNS topics and SQS queues
- **s3**: Buckets for application storage
- **alb**: Application Load Balancer (private)
- **api-gateway**: API Gateway with VPC Link for public access
- **helm**: Deploys services to EKS via Helm charts

The `main.tf` orchestrates all modules and wires outputs between them (e.g., VPC ID flows to EKS, ECR URLs flow to Helm deployments).

## CI/CD Pipeline

GitHub Actions workflow at `.github/workflows/deploy.yml`:
1. Builds and tests Java, Node.js, React services in parallel
2. Pushes Docker images to ECR with git SHA and `latest` tags
3. Deploys to EKS using Helm (only on main branch)
4. Uses `kubectl rollout status` to verify deployments

## Development Patterns

### Environment Variables

Services use these patterns:
- **Java**: Application properties with environment variable substitution
- **Node.js**: dotenv with `process.env.*` variables
- **Docker Compose**: Defines all vars in `docker-compose.yml`
- **AWS**: Secrets stored in AWS Secrets Manager, accessed via IRSA

For local development with LocalStack:
```bash
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=us-east-1
```

### Database Initialization

- `scripts/init-db.sql`: Creates `orderdb` and `userdb` databases
- Services use JPA/ORM for schema management
- PostgreSQL runs in docker-compose with health checks

### Testing LocalStack

```bash
# List S3 buckets
aws --endpoint-url=http://localhost:4566 s3 ls

# List SNS topics
aws --endpoint-url=http://localhost:4566 sns list-topics

# List SQS queues
aws --endpoint-url=http://localhost:4566 sqs list-queues
```

## Common Development Workflows

### Adding a New Microservice

1. Create service directory under `services/`
2. Add Dockerfile for containerization
3. Update `docker-compose.yml` with service definition
4. Add ECR repository to `infrastructure/terraform/main.tf` (ecr module)
5. Create Helm chart in `infrastructure/kubernetes/helm-charts/`
6. Add Helm deployment to `modules/helm/` Terraform module
7. Update CI/CD workflow in `.github/workflows/deploy.yml`

### Modifying Terraform Infrastructure

```bash
cd infrastructure/terraform
terraform plan -out=tfplan    # Review changes
terraform apply tfplan        # Apply changes
```

Important: Terraform state is stored in S3 backend (configure bucket in `main.tf`).

### Debugging Service Issues

```bash
# Local (Docker Compose)
docker-compose logs -f [service-name]
docker-compose restart [service-name]

# AWS (EKS)
kubectl logs -f deployment/[service-name]
kubectl describe pod [pod-name]
kubectl get events --sort-by='.lastTimestamp'
```

## Technology Stack

- **Languages**: Java 17, Node.js 18, React 18
- **Frameworks**: Spring Boot 3.2, Express 4.18, React Scripts 5.0
- **Infrastructure**: Terraform 1.5+, AWS EKS, Kubernetes, Helm 3
- **Database**: PostgreSQL 15, Spring Data JPA, pg (Node.js driver)
- **AWS Services**: EKS, RDS, ECR, SNS, SQS, S3, VPC, ALB, API Gateway, CloudWatch
- **Build Tools**: Maven 3.8+, npm
- **CI/CD**: GitHub Actions
- **Local Testing**: Docker Compose, LocalStack

## Important Notes

- **Never commit secrets**: Use AWS Secrets Manager and IRSA for AWS deployments
- **Database credentials**: Stored in Terraform-managed secrets, injected as env vars
- **Multi-AZ deployment**: All production resources should span 3 AZs (us-east-1a/b/c)
- **Health checks**: All services must expose health endpoints for Kubernetes probes
- **Logging**: Use structured JSON logging, all logs go to CloudWatch in AWS
- **IRSA**: Pods authenticate to AWS using IAM roles attached to Kubernetes service accounts
