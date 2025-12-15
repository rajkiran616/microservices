# Deployment Guide

## Quick Start

### Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5
- kubectl
- Helm >= 3.0
- Docker (for local development)

### Initial Deployment

1. **Clone and navigate to infrastructure**:
   ```bash
   cd infrastructure/terraform
   ```

2. **Create `terraform.tfvars`**:
   ```hcl
   # Required
   aws_region   = "us-east-1"
   project_name = "microservices-platform"
   environment  = "dev"
   
   # Alert configuration
   alert_emails = ["your-team@example.com"]
   
   # Budget limits (USD)
   monthly_budget_limit    = 1000
   eks_monthly_budget_limit = 400
   rds_monthly_budget_limit = 300
   
   # EKS Configuration
   eks_cluster_version   = "1.31"
   enable_eks_auto_mode = false  # Set to true when ready
   
   # API Gateway
   api_cors_allow_origins = ["https://yourdomain.com"]
   ```

3. **Initialize and deploy**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Configure kubectl**:
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name microservices-platform-dev
   ```

5. **Get API Gateway URL**:
   ```bash
   terraform output api_gateway_endpoint
   ```

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                  ┌──────▼──────┐
                  │   AWS WAF   │ ← DDoS, Rate Limiting
                  └──────┬──────┘
                         │
                  ┌──────▼──────────┐
                  │  API Gateway    │ ← Throttling, CORS
                  │   (HTTP API)    │
                  └──────┬──────────┘
                         │
                  ┌──────▼──────┐
                  │  VPC Link   │
                  └──────┬──────┘
                         │
        ┌────────────────▼────────────────┐
        │         Private ALB             │
        └────────────────┬────────────────┘
                         │
        ┌────────────────▼────────────────┐
        │        EKS Cluster              │
        │  (Auto Mode or Traditional)     │
        │                                 │
        │  ├─ Java Service (Orders)       │
        │  ├─ Node.js Service (Users)     │
        │  └─ React Frontend              │
        └─────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
   ┌────▼────┐    ┌─────▼─────┐    ┌────▼────┐
   │   RDS   │    │  S3/ECR   │    │ SNS/SQS │
   │  (PG)   │    │           │    │         │
   └─────────┘    └───────────┘    └─────────┘
```

### Components Deployed

| Component | Purpose | Cost (est.) |
|-----------|---------|-------------|
| **EKS Cluster** | Container orchestration | $72/mo |
| **EKS Nodes** | Compute (3x t3.medium) | $75/mo |
| **RDS PostgreSQL** | Database | $55/mo |
| **API Gateway** | Public API endpoint | $11/mo |
| **WAF** | Security rules | $6/mo |
| **ALB** | Load balancing | $22/mo |
| **NAT Gateways** | Private internet access | $97/mo |
| **GuardDuty** | Threat detection | $5/mo |
| **Backup** | RDS/EBS backups | $10/mo |
| **CloudWatch** | Monitoring/logging | $15/mo |
| **Total** | | **~$378/mo** |

## Enabling EKS Auto Mode

### When to Enable

- After testing traditional node groups
- When comfortable with AWS managing nodes
- For cost optimization (20-40% savings)
- To reduce operational overhead

### Migration Steps

1. **Update `terraform.tfvars`**:
   ```hcl
   enable_eks_auto_mode = true
   eks_cluster_version  = "1.31"
   ```

2. **Plan the migration**:
   ```bash
   terraform plan -out=auto-mode.tfplan
   ```

3. **Apply changes**:
   ```bash
   terraform apply auto-mode.tfplan
   ```

4. **Verify Auto Mode**:
   ```bash
   aws eks describe-cluster \
     --name microservices-platform-dev \
     --query 'cluster.computeConfig'
   ```

5. **Monitor workload migration**:
   ```bash
   kubectl get pods -A -w
   kubectl get nodes -w
   ```

See [EKS Auto Mode Guide](./eks-auto-mode-guide.md) for detailed migration procedures.

## Testing the Deployment

### 1. Health Check
```bash
API_URL=$(terraform output -raw api_gateway_endpoint)
curl $API_URL/health
```

Expected: `200 OK`

### 2. Create an Order (Java Service)
```bash
curl -X POST $API_URL/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 1,
    "productName": "Laptop",
    "quantity": 1,
    "totalAmount": 999.99
  }'
```

### 3. List Users (Node.js Service)
```bash
curl $API_URL/api/users
```

### 4. Check Kubernetes Pods
```bash
kubectl get pods -A
kubectl get svc -A
```

## Monitoring

### CloudWatch Dashboards

Access via AWS Console:
- **EKS Metrics**: Container Insights
- **API Gateway**: Request count, latency, errors
- **RDS**: CPU, connections, storage
- **WAF**: Allowed/blocked requests

### View Logs

```bash
# API Gateway logs
aws logs tail /aws/apigateway/microservices-platform-dev --follow

# Container logs
aws logs tail /aws/containerinsights/microservices-platform-dev/application --follow

# Kubernetes logs
kubectl logs -f deployment/java-service
kubectl logs -f deployment/nodejs-service
```

### Check Alarms

```bash
# List all alarms
aws cloudwatch describe-alarms --state-value ALARM

# Check specific alarm
aws cloudwatch describe-alarms \
  --alarm-names microservices-platform-dev-api-5xx-errors
```

## Security

### Enabled Security Controls

✅ **API Gateway WAF**
- Rate limiting: 2000 req/5min per IP
- AWS Managed Rules (OWASP Top 10, SQL injection)
- Geographic restrictions (optional)

✅ **GuardDuty**
- Threat detection for EKS, S3, EC2
- Malware scanning

✅ **Security Hub**
- CIS AWS Foundations Benchmark
- PCI DSS 3.2.1

✅ **AWS Config**
- Compliance rules enforcement
- Configuration history

✅ **Encryption**
- KMS keys for EKS, RDS, S3, EBS
- TLS 1.2+ for all traffic
- Secrets Manager for credentials

✅ **VPC Flow Logs**
- All network traffic logged
- S3 storage with lifecycle

### View Security Findings

```bash
# GuardDuty findings
aws guardduty list-findings --detector-id <detector-id>

# Security Hub findings
aws securityhub get-findings \
  --filters '{"SeverityLabel":[{"Value":"CRITICAL","Comparison":"EQUALS"}]}'

# Config compliance
aws configservice describe-compliance-by-config-rule
```

## Cost Management

### View Current Costs

```bash
# Check budgets
aws budgets describe-budgets --account-id <account-id>

# View cost and usage
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '30 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

### Cost Optimization

1. **After 3 months**: Purchase Compute Savings Plan
2. **Implement**: S3 Intelligent-Tiering
3. **Enable**: Environment scheduling for dev/test
4. **Review**: RDS instance sizing monthly

## Backup and Recovery

### Verify Backups

```bash
# List backup vaults
aws backup list-backup-vaults

# List recovery points
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name microservices-platform-dev-backup-vault
```

### Test Restore

```bash
# Restore RDS (example)
aws backup start-restore-job \
  --recovery-point-arn <recovery-point-arn> \
  --metadata file://restore-metadata.json \
  --iam-role-arn <backup-role-arn>
```

See [Disaster Recovery Guide](./disaster-recovery.md) for detailed procedures.

## Troubleshooting

### Pod Not Starting

```bash
# Describe pod
kubectl describe pod <pod-name>

# Check events
kubectl get events --sort-by='.lastTimestamp' | tail -20

# Check logs
kubectl logs <pod-name> --previous
```

### API Gateway Errors

```bash
# Check CloudWatch logs
aws logs filter-log-events \
  --log-group-name /aws/apigateway/microservices-platform-dev \
  --filter-pattern "5xx"

# Check WAF blocked requests
aws wafv2 get-sampled-requests \
  --web-acl-arn <waf-acl-arn> \
  --rule-metric-name rate-limit \
  --scope REGIONAL \
  --time-window StartTime=$(date -d '1 hour ago' +%s),EndTime=$(date +%s) \
  --max-items 10
```

### High Costs

```bash
# Check cost anomalies
aws ce get-anomalies \
  --monitor-arn <monitor-arn> \
  --date-interval Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d)

# Review top services
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

## Terraform Management

### Update Infrastructure

```bash
# Pull latest changes
git pull

# Review changes
terraform plan

# Apply changes
terraform apply
```

### Manage State

```bash
# View state
terraform show

# List resources
terraform state list

# Remove resource from state
terraform state rm <resource>
```

### Workspace Management

```bash
# Create workspace
terraform workspace new staging

# Switch workspace
terraform workspace select dev

# List workspaces
terraform workspace list
```

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/deploy.yml`) automatically:

1. **On Push to Feature Branch**:
   - Build and test services
   - Run security scans

2. **On Pull Request**:
   - Run full test suite
   - Generate Terraform plan

3. **On Merge to Main**:
   - Build Docker images
   - Push to ECR with SHA tags
   - Deploy to EKS via Helm
   - Verify deployment
   - Notify team

### Manual Deployment

```bash
# Build images
docker build -t java-service:latest services/java-service/
docker build -t nodejs-service:latest services/nodejs-service/
docker build -t react-app:latest frontend/react-app/

# Tag and push to ECR
ECR_URL=$(terraform output -raw ecr_registry_url)
docker tag java-service:latest $ECR_URL/java-service:latest
docker push $ECR_URL/java-service:latest

# Deploy with Helm
helm upgrade --install java-service \
  infrastructure/kubernetes/helm-charts/java-service/ \
  --set image.repository=$ECR_URL/java-service \
  --set image.tag=latest
```

## Next Steps

1. **Configure Custom Domain**: See [API Gateway Architecture](./api-gateway-architecture.md)
2. **Enable EKS Auto Mode**: See [EKS Auto Mode Guide](./eks-auto-mode-guide.md)
3. **Review Well-Architected**: See [Well-Architected Review](./well-architected-review.md)
4. **Implement Caching**: Add ElastiCache Redis module
5. **Set Up CloudFront**: For static asset CDN
6. **Test Disaster Recovery**: Monthly backup restoration tests

## Documentation

- [Architecture Overview](../README.md)
- [API Gateway Architecture](./api-gateway-architecture.md)
- [EKS Auto Mode Guide](./eks-auto-mode-guide.md)
- [Well-Architected Review](./well-architected-review.md)
- [Operations Guide](../WARP.md)

## Support

For issues or questions:
1. Check documentation in `/docs`
2. Review CloudWatch logs and alarms
3. Consult AWS Support (if applicable)
4. Review Well-Architected Framework recommendations
