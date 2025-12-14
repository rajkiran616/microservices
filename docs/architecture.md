# Reference Architecture

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          AWS Cloud                               │
│                                                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                       VPC                                  │  │
│  │                                                            │  │
│  │  ┌──────────────── Public Subnets ─────────────────┐     │  │
│  │  │                                                   │     │  │
│  │  │  ┌─────────┐         ┌─────────────────────┐   │     │  │
│  │  │  │   ALB   │────────▶│  React Frontend     │   │     │  │
│  │  │  │         │         │  (EKS Pod)          │   │     │  │
│  │  │  └─────────┘         └─────────────────────┘   │     │  │
│  │  │                                                   │     │  │
│  │  └───────────────────────────────────────────────────┘     │  │
│  │                                                            │  │
│  │  ┌──────────────── Private Subnets ────────────────┐     │  │
│  │  │                                                   │     │  │
│  │  │  ┌─────────────────────┐  ┌──────────────────┐ │     │  │
│  │  │  │   Java Service      │  │  Node.js Service │ │     │  │
│  │  │  │   (EKS Pod)         │  │  (EKS Pod)       │ │     │  │
│  │  │  └──────────┬──────────┘  └────────┬─────────┘ │     │  │
│  │  │             │                      │            │     │  │
│  │  │             │  ┌───────────────┐  │            │     │  │
│  │  │             └─▶│  RDS (Aurora) │◀─┘            │     │  │
│  │  │                │  PostgreSQL   │                │     │  │
│  │  │                └───────────────┘                │     │  │
│  │  │                                                   │     │  │
│  │  └───────────────────────────────────────────────────┘     │  │
│  │                                                            │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │     SNS     │  │     SQS     │  │     S3      │             │
│  │   Topics    │─▶│   Queues    │  │   Buckets   │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│                                                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │     ECR     │  │  Secrets    │  │ CloudWatch  │             │
│  │ Repositories│  │   Manager   │  │   Logs      │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

## Data Flow

1. **User Request**: Browser → ALB → React Frontend Pod
2. **API Calls**: React → ALB → Java/Node.js Services
3. **Database**: Services → RDS Aurora (private subnet)
4. **Async Processing**: Java Service → SNS → SQS → Node.js Service
5. **File Storage**: Services → S3 for uploads/downloads
6. **Logs**: All Pods → CloudWatch Logs

## Service Communication

### Java Service (Order Processing)
- **Endpoints**: 
  - `POST /api/orders` - Create order
  - `GET /api/orders/{id}` - Get order
  - `PUT /api/orders/{id}` - Update order
- **Publishes to**: SNS topic `order-events`
- **Database**: PostgreSQL (order tables)

### Node.js Service (User Management)
- **Endpoints**:
  - `POST /api/users` - Create user
  - `GET /api/users/{id}` - Get user profile
  - `PUT /api/users/{id}` - Update user
- **Subscribes to**: SQS queue `order-notifications`
- **Database**: PostgreSQL (user tables)

### React Frontend
- **Features**:
  - User authentication
  - Order management UI
  - Real-time notifications
- **Calls**: Both Java and Node.js services via API Gateway pattern

## Security Architecture

### Network Security
- VPC with isolated public/private subnets
- Security groups restricting traffic between services
- NAT Gateway for private subnet internet access
- Network ACLs for subnet-level controls

### Application Security
- IRSA (IAM Roles for Service Accounts) for pod permissions
- Secrets Manager for sensitive configuration
- TLS/SSL for all external communication
- Container image scanning in ECR

### Database Security
- RDS in private subnet (no internet access)
- Encryption at rest and in transit
- Automated backups with point-in-time recovery
- Database parameter groups for hardening

## Scalability

### Auto-scaling
- **HPA**: Horizontal Pod Autoscaler based on CPU/memory
- **Cluster Autoscaler**: EKS node auto-scaling
- **RDS**: Multi-AZ with read replicas option

### High Availability
- Multi-AZ deployment for all services
- ALB distributes traffic across AZs
- RDS automatic failover
- SNS/SQS for decoupled async processing

## Monitoring Strategy

### Metrics
- CloudWatch Container Insights for EKS
- Custom application metrics
- RDS Performance Insights

### Logging
- Centralized logging to CloudWatch Logs
- Log aggregation from all pods
- Structured JSON logging

### Alerting
- CloudWatch Alarms for critical metrics
- SNS notifications for alerts
- Integration with PagerDuty/Slack

## Disaster Recovery

- **RTO**: 30 minutes
- **RPO**: 5 minutes
- Automated RDS backups (retained 7 days)
- Infrastructure as Code for rapid rebuild
- Multi-region failover capability (future enhancement)
