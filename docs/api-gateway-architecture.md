# API Gateway Architecture

## Overview

The API Gateway provides a secure, scalable, and highly available public entry point to your microservices platform. It sits in front of your private Application Load Balancer (ALB), adding multiple layers of security, monitoring, and traffic management.

## Architecture Diagram

```
Internet
   ↓
[AWS WAF] ← DDoS Protection, Rate Limiting, Security Rules
   ↓
[API Gateway HTTP API] ← Throttling, CORS, Logging
   ↓
[VPC Link] ← Secure connection to private network
   ↓
[Private ALB] ← Load balancing across services
   ↓
[EKS Services] ← Java Service, Node.js Service, React Frontend
   ↓
[RDS/S3/SQS] ← Backend resources
```

## Key Features

### 1. Security (Security Pillar)

#### AWS WAF Integration
- **Rate Limiting**: 2000 requests per 5 minutes per IP (configurable)
- **AWS Managed Rules**:
  - Common Rule Set: Protects against OWASP Top 10
  - Known Bad Inputs: Blocks malicious patterns
  - SQL Injection: Prevents SQL injection attacks
- **Geographic Restrictions**: Optional country-based access control
- **Automatic DDoS Protection**: Layer 7 DDoS mitigation

#### VPC Link Security
- API Gateway connects to ALB via VPC Link (not public internet)
- ALB remains in private subnets
- Services never directly exposed to internet
- Security groups control traffic flow

### 2. Traffic Management

#### Throttling
- **Burst Limit**: 5000 requests (spike capacity)
- **Rate Limit**: 2000 requests/second (steady state)
- Protects backend services from overload
- Returns 429 Too Many Requests when limits exceeded

#### CORS Configuration
- Pre-configured for web applications
- Supports credentials
- Customizable origins, methods, and headers

### 3. Observability (Operational Excellence Pillar)

#### CloudWatch Logging
- Full request/response logging
- Structured JSON format
- Fields captured:
  - Request ID
  - Source IP
  - HTTP method and path
  - Status code
  - Response time
  - Integration errors

#### CloudWatch Alarms
- **4xx Errors**: Alert when client errors exceed 100 in 5 minutes
- **5xx Errors**: Alert when server errors exceed 10 in 5 minutes
- **High Latency**: Alert when average latency exceeds 1000ms
- **WAF Blocked Requests**: Alert when WAF blocks >1000 requests

### 4. Cost Optimization (Cost Pillar)

- **HTTP API vs REST API**: 70% cost savings using HTTP API
- **No NAT Gateway costs**: API Gateway handles public internet access
- **Pay per request**: No idle charges
- **AWS Managed Service**: No infrastructure to maintain

### 5. Performance (Performance Efficiency Pillar)

- **HTTP API**: Lower latency than REST API (average ~30% faster)
- **Regional endpoint**: Optimized for single-region deployments
- **CloudFront integration**: Can add CDN if needed
- **Connection pooling**: Efficient connections to ALB

## API Routes

### Service Routes

#### Java Service (Orders)
```
POST   /api/orders         - Create new order
GET    /api/orders         - List orders
GET    /api/orders/{id}    - Get order by ID
PUT    /api/orders/{id}    - Update order
DELETE /api/orders/{id}    - Delete order
```

Backend: `http://private-alb/api/orders/*`

#### Node.js Service (Users)
```
POST   /api/users          - Create new user
GET    /api/users          - List users
GET    /api/users/{id}     - Get user by ID
PUT    /api/users/{id}     - Update user
DELETE /api/users/{id}     - Delete user
```

Backend: `http://private-alb/api/users/*`

#### Health Check
```
GET    /health             - Health check endpoint
```

Returns: `200 OK` if services are healthy

### Default Route
All other requests are forwarded to the ALB with the original path preserved.

## Configuration

### Environment Variables

Set these in `terraform.tfvars`:

```hcl
# API Gateway Throttling
api_throttle_burst_limit = 5000
api_throttle_rate_limit  = 2000
api_waf_rate_limit       = 2000

# CORS Configuration
api_cors_allow_origins = ["https://yourdomain.com", "https://app.yourdomain.com"]

# Geographic Restrictions (optional)
api_allowed_countries = ["US", "CA", "GB"]  # Empty = allow all

# Custom Domain (optional)
api_custom_domain_name  = "api.yourdomain.com"
acm_certificate_arn     = "arn:aws:acm:us-east-1:..."
```

### Custom Domain Setup

1. **Create ACM Certificate**:
   ```bash
   aws acm request-certificate \
     --domain-name api.yourdomain.com \
     --validation-method DNS \
     --region us-east-1
   ```

2. **Validate Certificate**: Add DNS records in Route53

3. **Set Variables**:
   ```hcl
   api_custom_domain_name  = "api.yourdomain.com"
   acm_certificate_arn     = "arn:aws:acm:..."
   ```

4. **Apply Terraform**:
   ```bash
   terraform apply
   ```

5. **Create DNS Record**:
   ```bash
   # Get the API Gateway domain name from Terraform output
   terraform output api_gateway_custom_domain
   
   # Create CNAME or Alias record in Route53
   api.yourdomain.com -> <api-gateway-domain>
   ```

## Testing

### Health Check
```bash
curl https://<api-gateway-url>/health
```

Expected: `200 OK`

### Create Order (Java Service)
```bash
curl -X POST https://<api-gateway-url>/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 1,
    "productName": "Laptop",
    "quantity": 1,
    "totalAmount": 999.99
  }'
```

### Get Users (Node.js Service)
```bash
curl https://<api-gateway-url>/api/users
```

### Test Rate Limiting
```bash
# Send 2500 requests in quick succession
for i in {1..2500}; do
  curl https://<api-gateway-url>/health &
done

# You should see 429 responses after hitting the limit
```

### Test WAF (SQL Injection)
```bash
# This should be blocked by WAF
curl "https://<api-gateway-url>/api/users?id=1' OR '1'='1"

# Response: 403 Forbidden (blocked by WAF)
```

## Monitoring

### CloudWatch Dashboards

View metrics in AWS Console:
1. Go to **CloudWatch > Dashboards**
2. Create custom dashboard with:
   - API Gateway 4xx/5xx errors
   - API Gateway request count
   - API Gateway latency
   - WAF blocked requests
   - WAF allowed requests

### CloudWatch Logs

View access logs:
```bash
aws logs tail /aws/apigateway/microservices-platform-dev --follow
```

### CloudWatch Alarms

Check alarm status:
```bash
aws cloudwatch describe-alarms --alarm-name-prefix microservices-platform-dev-api
```

## WAF Management

### View Blocked IPs
```bash
aws wafv2 get-sampled-requests \
  --web-acl-arn <waf-web-acl-arn> \
  --rule-metric-name rate-limit \
  --scope REGIONAL \
  --time-window StartTime=<timestamp>,EndTime=<timestamp> \
  --max-items 100
```

### Update Rate Limit
Update `api_waf_rate_limit` in `terraform.tfvars` and apply:
```bash
terraform apply -target=module.api_gateway
```

### Add IP Whitelist (if needed)
Modify `modules/api-gateway/main.tf` to add IP set rules.

## Troubleshooting

### Issue: 403 Forbidden from WAF

**Symptoms**: Legitimate requests blocked by WAF

**Solution**:
1. Check CloudWatch Logs for blocked requests
2. Identify the WAF rule blocking the request
3. Either:
   - Adjust the rule threshold
   - Add exception for specific pattern
   - Whitelist the IP if internal testing

### Issue: 504 Gateway Timeout

**Symptoms**: Requests timing out

**Causes**:
1. ALB target unhealthy
2. Backend service slow/down
3. VPC Link misconfiguration

**Solution**:
```bash
# Check ALB target health
aws elbv2 describe-target-health --target-group-arn <tg-arn>

# Check EKS pod status
kubectl get pods -n default

# Check service endpoints
kubectl get endpoints
```

### Issue: High Latency

**Symptoms**: Slow response times

**Investigation**:
```bash
# Check API Gateway metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApiGateway \
  --metric-name Latency \
  --dimensions Name=ApiId,Value=<api-id> \
  --start-time <timestamp> \
  --end-time <timestamp> \
  --period 300 \
  --statistics Average

# Check ALB metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=<alb-arn-suffix> \
  --period 300 \
  --statistics Average
```

### Issue: CORS Errors

**Symptoms**: Browser blocking requests due to CORS

**Solution**: Update CORS configuration in `terraform.tfvars`:
```hcl
api_cors_allow_origins = ["https://yourdomain.com"]
```

Then apply:
```bash
terraform apply -target=module.api_gateway
```

## Cost Estimation

### Typical Monthly Costs (dev environment)

| Component | Usage | Cost |
|-----------|-------|------|
| API Gateway HTTP API | 1M requests | $1.00 |
| VPC Link | 1 hour | $10.80 |
| WAF | 1M requests + 5 rules | $6.00 |
| CloudWatch Logs | 5GB | $2.50 |
| Data Transfer | 10GB out | $0.90 |
| **Total** | | **~$21/month** |

### Production Costs (100M requests/month)

| Component | Usage | Cost |
|-----------|-------|------|
| API Gateway HTTP API | 100M requests | $100.00 |
| VPC Link | 744 hours | $10.80 |
| WAF | 100M requests + 5 rules | $506.00 |
| CloudWatch Logs | 50GB | $25.00 |
| Data Transfer | 1TB out | $90.00 |
| **Total** | | **~$732/month** |

## Best Practices

### 1. Use Custom Domains
- Better branding
- Easier to migrate later
- Certificate management via ACM

### 2. Enable Request Validation
- Reduce backend load
- Catch errors early
- Improve security

### 3. Implement API Keys (if needed)
- For partner integrations
- Usage tracking per customer
- Rate limiting per key

### 4. Use Usage Plans
- Different tiers (free, pro, enterprise)
- Tiered rate limits
- Monetization ready

### 5. Monitor and Alert
- Set up dashboards
- Configure alarms
- Review logs regularly

### 6. Regular WAF Review
- Check blocked requests
- Update rules as needed
- Monitor false positives

### 7. Load Testing
- Test before production
- Validate throttle limits
- Verify failover behavior

## Security Checklist

- [ ] WAF enabled with managed rules
- [ ] Rate limiting configured
- [ ] TLS 1.2 minimum enforced
- [ ] Access logs enabled
- [ ] CloudWatch alarms configured
- [ ] VPC Link in private subnets
- [ ] ALB not publicly accessible
- [ ] CORS properly configured
- [ ] Geographic restrictions (if needed)
- [ ] API keys (if needed)
- [ ] Request validation enabled
- [ ] Regular security reviews scheduled

## References

- [AWS API Gateway HTTP APIs](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api.html)
- [AWS WAF Developer Guide](https://docs.aws.amazon.com/waf/latest/developerguide/)
- [API Gateway VPC Links](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vpc-links.html)
- [Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
