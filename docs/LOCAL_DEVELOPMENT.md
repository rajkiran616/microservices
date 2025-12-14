# Local Development Guide

## Prerequisites

- Docker Desktop or Docker Engine
- Docker Compose
- Node.js 18+ (for frontend development)
- Java 17+ & Maven 3.8+ (for Java service development)
- AWS CLI (optional, for AWS resource testing)

## Quick Start

### 1. Clone and Navigate

```bash
cd aws-microservices-platform
```

### 2. Start All Services

```bash
docker-compose up --build
```

This will start:
- PostgreSQL (port 5432)
- LocalStack (AWS services mock - port 4566)
- Java Order Service (port 8080)
- Node.js User Service (port 3000)
- React Frontend (port 3001)

### 3. Access Services

- **Frontend**: http://localhost:3001
- **Java Service**: http://localhost:8080/api/orders
- **Node.js Service**: http://localhost:3000/api/users
- **Java Health**: http://localhost:8080/actuator/health
- **Node.js Health**: http://localhost:3000/health

### 4. Test the Application

Open http://localhost:3001 in your browser and:
1. Click "Create Test User" to create a user
2. Click "Create Test Order" to create an order
3. Watch the SNS→SQS message flow in the Node.js service logs

## Development Workflows

### Java Service Development

```bash
cd services/java-service

# Run locally without Docker
mvn spring-boot:run

# Run tests
mvn test

# Build JAR
mvn clean package
```

### Node.js Service Development

```bash
cd services/nodejs-service

# Install dependencies
npm install

# Run locally with hot reload
npm run dev

# Run tests
npm test
```

### React Frontend Development

```bash
cd frontend/react-app

# Install dependencies
npm install

# Start development server
npm start

# Build for production
npm run build
```

## LocalStack (AWS Services Mock)

LocalStack provides local AWS service emulation:

### Check LocalStack Services

```bash
# List S3 buckets
aws --endpoint-url=http://localhost:4566 s3 ls

# List SNS topics
aws --endpoint-url=http://localhost:4566 sns list-topics

# List SQS queues
aws --endpoint-url=http://localhost:4566 sqs list-queues
```

### Environment Variables for LocalStack

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
```

## Database Access

### Connect to PostgreSQL

```bash
# Using psql
psql -h localhost -U postgres -d orderdb
psql -h localhost -U postgres -d userdb

# Password: postgres
```

### View Database Logs

```bash
docker-compose logs postgres
```

## Debugging

### View Service Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f java-service
docker-compose logs -f nodejs-service
docker-compose logs -f react-frontend
```

### Stop Services

```bash
# Stop all
docker-compose down

# Stop and remove volumes (clean slate)
docker-compose down -v
```

### Rebuild Services

```bash
# Rebuild specific service
docker-compose up --build java-service

# Rebuild all
docker-compose up --build
```

## Testing Message Flow

### 1. Create an Order (Java Service)

```bash
curl -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 1,
    "productName": "Laptop",
    "quantity": 1,
    "totalAmount": 999.99
  }'
```

### 2. Watch SQS Messages

The Node.js service will automatically consume messages from the SQS queue.

Check logs:
```bash
docker-compose logs -f nodejs-service
```

## Common Issues

### Port Conflicts

If ports are already in use:
```bash
# Check what's using the port
lsof -i :8080
lsof -i :3000
lsof -i :3001

# Kill the process or change ports in docker-compose.yml
```

### Database Connection Issues

```bash
# Restart PostgreSQL
docker-compose restart postgres

# Check PostgreSQL is healthy
docker-compose ps
```

### LocalStack Not Working

```bash
# Restart LocalStack
docker-compose restart localstack

# Check LocalStack logs
docker-compose logs localstack
```

## Clean Up

```bash
# Stop all services
docker-compose down

# Remove all volumes and images
docker-compose down -v --rmi all

# Remove orphaned containers
docker system prune -a
```

## Next Steps

Once local development is working:
1. Review the architecture documentation in `docs/architecture.md`
2. Deploy to AWS using Terraform in `infrastructure/terraform/`
3. Set up CI/CD pipeline with `.github/workflows/`
