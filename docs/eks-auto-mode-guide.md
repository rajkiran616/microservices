# EKS Auto Mode Migration Guide

## Overview

EKS Auto Mode automates node provisioning, scaling, and lifecycle management, reducing operational overhead by up to 80%. AWS manages node groups, instance selection, and capacity optimization automatically.

## What is EKS Auto Mode?

EKS Auto Mode is a fully automated compute management feature for Amazon EKS that:
- **Automatically provisions nodes** based on pod resource requirements
- **Selects optimal instance types** using AWS recommendations
- **Scales dynamically** without manual configuration
- **Handles node lifecycle** including updates and replacements
- **Optimizes costs** through intelligent bin-packing and Spot instance support

## Benefits

### Operational Excellence
- **No manual node group management** - AWS handles everything
- **Automatic scaling** - Nodes added/removed based on demand
- **Simplified operations** - Fewer configurations to maintain
- **Reduced toil** - No more capacity planning

### Cost Optimization
- **Better bin-packing** - More efficient resource utilization
- **Spot instance support** - Automatic Spot integration where appropriate
- **Right-sizing** - Optimal instance types for workloads
- **No over-provisioning** - Pay only for what you need

### Reliability
- **AWS-managed updates** - Automatic node patching
- **Health monitoring** - Proactive issue detection
- **Multi-AZ by default** - Built-in high availability
- **Graceful draining** - Workload-aware node replacement

## Prerequisites

### Cluster Requirements
- **EKS version**: 1.31 or later
- **VPC**: Existing VPC with private subnets
- **IAM**: EKS cluster role with required permissions

### Current State Check
```bash
# Check current EKS version
kubectl version --short

# Check node groups
kubectl get nodes

# Check current capacity
kubectl top nodes
```

## Migration Strategies

### Option 1: Blue-Green Cluster Migration (Recommended for Production)

**Best for**: Zero-downtime production migration

**Steps**:
1. Create new cluster with Auto Mode enabled
2. Deploy applications to new cluster
3. Switch traffic to new cluster
4. Decommission old cluster

**Downtime**: None

**Risk**: Low

### Option 2: In-Place Migration (Recommended for Dev/Test)

**Best for**: Non-production environments

**Steps**:
1. Enable Auto Mode on existing cluster
2. Drain and remove old node groups
3. Verify workloads reschedule to Auto Mode nodes

**Downtime**: Brief during node transitions

**Risk**: Medium

### Option 3: Gradual Migration

**Best for**: Risk-averse production migrations

**Steps**:
1. Enable Auto Mode
2. Gradually reduce old node group size
3. Monitor workload migration
4. Remove old node groups when confident

**Downtime**: None

**Risk**: Low

## Step-by-Step Migration

### Phase 1: Pre-Migration (Day 0)

#### 1. Review Current Configuration
```bash
# Export current node group configuration
aws eks describe-nodegroup \
  --cluster-name microservices-platform-dev \
  --nodegroup-name microservices-platform-dev-node-group \
  > current-nodegroup.json

# List all workloads
kubectl get deployments,statefulsets,daemonsets -A
```

#### 2. Document Pod Requirements
```bash
# Check pod resource requests/limits
kubectl get pods -A -o json | jq '.items[] | {
  name: .metadata.name,
  namespace: .metadata.namespace,
  requests: .spec.containers[].resources.requests,
  limits: .spec.containers[].resources.limits
}'
```

#### 3. Backup Current State
```bash
# Backup all Kubernetes resources
kubectl get all -A -o yaml > kubernetes-backup.yaml

# Backup persistent volumes
kubectl get pv,pvc -A -o yaml > pv-backup.yaml
```

### Phase 2: Enable Auto Mode (Day 1)

#### 1. Update Terraform Configuration

Edit `terraform.tfvars`:
```hcl
# Enable EKS Auto Mode
enable_eks_auto_mode = true

# Update cluster version if needed
eks_cluster_version = "1.31"

# Configure Auto Mode node pools
eks_auto_mode_node_pools = ["general-purpose"]
```

#### 2. Plan and Apply
```bash
cd infrastructure/terraform

# Review changes
terraform plan -out=eks-auto-mode.tfplan

# Apply changes
terraform apply eks-auto-mode.tfplan
```

#### 3. Verify Auto Mode is Enabled
```bash
# Check cluster configuration
aws eks describe-cluster \
  --name microservices-platform-dev \
  --query 'cluster.computeConfig'

# Should show:
# {
#   "enabled": true,
#   "nodePools": ["general-purpose"]
# }
```

### Phase 3: Workload Migration (Day 1-2)

#### 1. Cordon Old Nodes
```bash
# Prevent new pods from scheduling on old nodes
kubectl get nodes -l node-group=old | \
  awk '{print $1}' | \
  xargs -I {} kubectl cordon {}
```

#### 2. Drain Workloads Gradually
```bash
# Drain one node at a time
for node in $(kubectl get nodes -l node-group=old -o name); do
  echo "Draining $node"
  kubectl drain $node \
    --ignore-daemonsets \
    --delete-emptydir-data \
    --grace-period=300
  
  # Wait for pods to reschedule
  sleep 120
  
  # Verify pods are healthy
  kubectl get pods -A | grep -v Running
done
```

#### 3. Monitor Auto Mode Provisioning
```bash
# Watch new nodes being created
watch kubectl get nodes

# Check pod events
kubectl get events -A --sort-by='.lastTimestamp' | grep -i node
```

### Phase 4: Validation (Day 2-3)

#### 1. Verify All Workloads are Running
```bash
# Check pod status
kubectl get pods -A | grep -v Running

# Check deployment status
kubectl get deployments -A

# Verify services
kubectl get svc -A
```

#### 2. Test Application Endpoints
```bash
# Test via API Gateway
curl https://$(terraform output -raw api_gateway_endpoint)/health

# Test specific services
curl -X POST https://$(terraform output -raw api_gateway_endpoint)/api/orders \
  -H "Content-Type: application/json" \
  -d '{"userId": 1, "productName": "Test", "quantity": 1, "totalAmount": 10.00}'
```

#### 3. Check Node Utilization
```bash
# Check CPU/Memory usage
kubectl top nodes

# Verify efficient packing
kubectl describe nodes | grep -A 5 "Allocated resources"
```

### Phase 5: Cleanup (Day 3-7)

#### 1. Remove Old Node Groups

**Terraform approach** (automatic):
```bash
# Old node groups are automatically removed when Auto Mode is enabled
# Verify no manual node groups remain
aws eks list-nodegroups --cluster-name microservices-platform-dev
```

**Manual approach** (if needed):
```bash
# Delete old node group
aws eks delete-nodegroup \
  --cluster-name microservices-platform-dev \
  --nodegroup-name old-node-group
```

#### 2. Clean Up Terraform Variables

Edit `terraform.tfvars`:
```hcl
# Remove old node group variables (optional - they're ignored when Auto Mode is enabled)
# eks_node_instance_types = ["t3.medium"]
# eks_node_desired_size   = 3
# eks_node_min_size       = 2
# eks_node_max_size       = 5
```

#### 3. Update Documentation
- Update runbooks with Auto Mode procedures
- Remove old node group scaling playbooks
- Document new monitoring approach

## Auto Mode Configuration

### Node Pools

Auto Mode supports different node pool types:

#### General Purpose (Default)
```hcl
eks_auto_mode_node_pools = ["general-purpose"]
```
- **Use for**: Most workloads
- **Instance types**: Broad selection (t3, m5, m6, c5, c6, r5, r6)
- **Capacity types**: On-Demand and Spot

#### System
```hcl
eks_auto_mode_node_pools = ["general-purpose", "system"]
```
- **Use for**: Critical system workloads
- **Instance types**: Stable, general-purpose instances
- **Capacity types**: On-Demand only

### Pod Resource Requirements

Auto Mode selects instances based on pod specifications:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
      - name: app
        resources:
          requests:
            cpu: "500m"
            memory: "512Mi"
          limits:
            cpu: "1000m"
            memory: "1Gi"
```

**Best Practices**:
- Always specify resource requests
- Set realistic limits
- Use requests for scheduling decisions
- Auto Mode will provision appropriately sized nodes

## Monitoring Auto Mode

### CloudWatch Metrics

Key metrics to monitor:

```bash
# Node count
aws cloudwatch get-metric-statistics \
  --namespace AWS/EKS \
  --metric-name cluster_node_count \
  --dimensions Name=ClusterName,Value=microservices-platform-dev \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Failed nodes
aws cloudwatch get-metric-statistics \
  --namespace AWS/EKS \
  --metric-name cluster_failed_node_count \
  --dimensions Name=ClusterName,Value=microservices-platform-dev \
  --period 300 \
  --statistics Sum
```

### Kubernetes Events

```bash
# Watch Auto Mode events
kubectl get events -A \
  --field-selector source=eks-auto-mode \
  --sort-by='.lastTimestamp'

# Monitor pending pods
kubectl get pods -A | grep Pending

# Check pod scheduling events
kubectl describe pod <pod-name> | grep Events -A 10
```

### Container Insights

```bash
# View in CloudWatch
aws logs tail /aws/containerinsights/microservices-platform-dev/performance --follow

# Check node metrics
kubectl top nodes
```

## Troubleshooting

### Issue: Pods Stuck in Pending

**Symptoms**: Pods not scheduling, remain in Pending state

**Diagnosis**:
```bash
# Check pod events
kubectl describe pod <pod-name>

# Common causes:
# - Insufficient capacity
# - Resource requests too large
# - Node selectors/taints
```

**Solution**:
```bash
# Check if resource requests are reasonable
kubectl get pod <pod-name> -o json | jq '.spec.containers[].resources'

# Remove unnecessary node selectors
kubectl edit deployment <deployment-name>

# Verify Auto Mode is active
aws eks describe-cluster --name microservices-platform-dev \
  --query 'cluster.computeConfig'
```

### Issue: High Node Churn

**Symptoms**: Nodes constantly being replaced

**Diagnosis**:
```bash
# Check node age
kubectl get nodes -o json | jq -r '.items[] | "\(.metadata.name) \(.metadata.creationTimestamp)"'

# Check termination events
kubectl get events -A | grep -i terminate
```

**Solution**:
```bash
# Review pod resource requests (might be causing rightsizing)
kubectl get pods -A -o json | jq '.items[] | .spec.containers[].resources'

# Ensure stable workload patterns
# Consider using PodDisruptionBudgets
```

### Issue: Unexpected Instance Types

**Symptoms**: Auto Mode selecting different instance types than expected

**Diagnosis**:
```bash
# Check current instance types
kubectl get nodes -o custom-columns=NAME:.metadata.name,INSTANCE:.metadata.labels.node\\.kubernetes\\.io/instance-type

# Review pod requirements
kubectl get pods -A -o json | jq '.items[] | {
  name: .metadata.name,
  cpu: .spec.containers[].resources.requests.cpu,
  memory: .spec.containers[].resources.requests.memory
}'
```

**Solution**:
- Auto Mode optimizes for cost and performance
- If specific instance types needed, use node selectors:
  ```yaml
  nodeSelector:
    node.kubernetes.io/instance-type: m5.large
  ```
- Or specify requirements more precisely

### Issue: Cross-AZ Data Transfer Costs

**Symptoms**: Higher than expected data transfer costs

**Diagnosis**:
```bash
# Check pod distribution across AZs
kubectl get pods -A -o wide | awk '{print $8}' | sort | uniq -c

# Check service endpoints
kubectl get endpoints -A
```

**Solution**:
```yaml
# Use topology spread constraints
spec:
  topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
```

## Cost Optimization with Auto Mode

### 1. Spot Instance Integration

Auto Mode automatically uses Spot instances where appropriate:
- Non-critical workloads
- Stateless applications
- Batch processing

**No configuration needed** - Auto Mode handles Spot lifecycle.

### 2. Right-Sizing

Auto Mode continuously optimizes:
- Bins pods efficiently
- Scales down underutilized nodes
- Consolidates workloads

**Monitor savings**:
```bash
# Compare costs before/after in Cost Explorer
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter file://eks-filter.json
```

### 3. Reserved Instance / Savings Plans

Auto Mode works with RIs and Savings Plans:
- Auto Mode selects instance families covered by commitments
- Maximizes RI/SP utilization
- Reduces overall compute costs by 40-60%

## Comparison: Traditional vs Auto Mode

| Aspect | Traditional Node Groups | EKS Auto Mode |
|--------|------------------------|---------------|
| **Node Management** | Manual | Automated |
| **Scaling** | Configure ASG rules | Automatic based on pods |
| **Instance Selection** | Manual | AWS-optimized |
| **Updates** | Manual or managed node groups | Fully automated |
| **Spot Integration** | Manual configuration | Automatic |
| **Bin-Packing** | Basic | Advanced |
| **Cost** | Manual optimization | Automatic optimization |
| **Operational Overhead** | High | Minimal |
| **Learning Curve** | Moderate | Low |

## Best Practices

### 1. Always Specify Resource Requests
```yaml
resources:
  requests:
    cpu: "250m"
    memory: "256Mi"
```

### 2. Use PodDisruptionBudgets
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-app-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: my-app
```

### 3. Implement Health Checks
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
```

### 4. Use Topology Spread Constraints
```yaml
topologySpreadConstraints:
- maxSkew: 1
  topologyKey: topology.kubernetes.io/zone
  whenUnsatisfiable: DoNotSchedule
```

### 5. Monitor and Alert
- Set up CloudWatch alarms for node count
- Monitor pending pods
- Track cost trends
- Review Container Insights regularly

## Rollback Procedure

If you need to rollback to traditional node groups:

### 1. Update Terraform
```hcl
# terraform.tfvars
enable_eks_auto_mode = false

# Restore old values
eks_node_instance_types = ["t3.medium"]
eks_node_desired_size   = 3
eks_node_min_size       = 2
eks_node_max_size       = 5
```

### 2. Apply Changes
```bash
terraform apply
```

### 3. Verify
```bash
# Check node groups are created
aws eks list-nodegroups --cluster-name microservices-platform-dev

# Wait for nodes to be ready
kubectl get nodes -w
```

### 4. Drain Auto Mode Nodes
```bash
# If any Auto Mode nodes remain
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

## FAQ

**Q: Can I use Auto Mode with existing node groups?**
A: No, Auto Mode replaces traditional node groups. You must migrate.

**Q: Does Auto Mode support Windows nodes?**
A: Currently, Auto Mode is Linux-only (as of EKS 1.31).

**Q: Can I specify exact instance types?**
A: Not directly. Use node selectors to influence, but Auto Mode makes final decision.

**Q: What about GPU workloads?**
A: Specify GPU requirements in pod specs, Auto Mode will provision GPU instances.

**Q: Is there a cost for Auto Mode?**
A: No additional charge. Standard EC2 and EKS pricing applies.

**Q: Can I disable Auto Mode temporarily?**
A: No. Once enabled, you must migrate workloads to disable it.

**Q: Does Auto Mode work with Fargate?**
A: Yes, both can coexist. Use Fargate profiles for serverless pods.

**Q: What about cluster autoscaler?**
A: Not needed. Auto Mode handles scaling automatically.

## References

- [AWS EKS Auto Mode Documentation](https://docs.aws.amazon.com/eks/latest/userguide/auto-mode.html)
- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Cost Optimization on EKS](https://aws.amazon.com/blogs/containers/cost-optimization-for-kubernetes-on-aws/)
