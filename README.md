# NLQ System Kubernetes Deployment

This directory contains Kubernetes manifests for deploying the Natural Language Query (NLQ) system.

## Prerequisites

- Kubernetes cluster (v1.20+)
- kubectl configured to access your cluster
- Docker images built and pushed to your registry
- Ingress controller (nginx recommended)
- cert-manager (for TLS certificates, optional)

## Quick Start

1. **Update secrets** - Edit `secret.yaml` with your actual values:
   ```bash
   # Encode your values in base64
   echo -n "your_password" | base64
   echo -n "your_gemini_api_key" | base64
   ```

2. **Deploy the system**:
   ```bash
   kubectl apply -k .
   ```

3. **Check deployment status**:
   ```bash
   kubectl get pods -n nlq-system
   kubectl get services -n nlq-system
   ```

4. **Access the application**:
   - Add `nlq.local` to your `/etc/hosts` file pointing to your ingress IP
   - Visit `http://nlq.local` in your browser

## Components

### Core Services
- **PostgreSQL with pgvector**: Database with vector extension
- **NLQ Backend**: Node.js API service
- **NLQ Frontend**: React application

### Auto-scaling
- **Backend HPA**: Scales 2-10 replicas based on CPU/memory
- **Frontend HPA**: Scales 2-8 replicas based on CPU/memory

### Networking
- **Ingress**: Routes traffic to frontend and backend
- **Services**: Internal service discovery

## Configuration

### Environment Variables
All configuration is managed through ConfigMaps and Secrets:

- **ConfigMap** (`configmap.yaml`): Non-sensitive configuration
- **Secret** (`secret.yaml`): Sensitive data (passwords, API keys)

### Resource Limits
Default resource requests and limits:
- **Backend**: 256Mi-1Gi memory, 100m-500m CPU
- **Frontend**: 128Mi-512Mi memory, 50m-250m CPU
- **PostgreSQL**: 512Mi-2Gi memory, 250m-1000m CPU

## Monitoring

### Health Checks
- **Liveness probes**: Ensure containers are running
- **Readiness probes**: Ensure containers are ready to serve traffic

### Metrics
- CPU and memory utilization for auto-scaling
- Custom application metrics (if implemented)

## Scaling

### Horizontal Pod Autoscaler (HPA)
- **Backend**: 2-10 replicas, scales at 70% CPU, 80% memory
- **Frontend**: 2-8 replicas, scales at 70% CPU, 80% memory

### Manual Scaling
```bash
# Scale backend
kubectl scale deployment nlq-backend --replicas=5 -n nlq-system

# Scale frontend
kubectl scale deployment nlq-frontend --replicas=3 -n nlq-system
```

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n nlq-system
kubectl describe pod <pod-name> -n nlq-system
```

### View Logs
```bash
# Backend logs
kubectl logs -f deployment/nlq-backend -n nlq-system

# Frontend logs
kubectl logs -f deployment/nlq-frontend -n nlq-system

# PostgreSQL logs
kubectl logs -f deployment/postgres -n nlq-system
```

### Check Services
```bash
kubectl get services -n nlq-system
kubectl describe service <service-name> -n nlq-system
```

### Check Ingress
```bash
kubectl get ingress -n nlq-system
kubectl describe ingress nlq-ingress -n nlq-system
```

## Production Considerations

### Security
- Use proper TLS certificates
- Implement network policies
- Use RBAC for service accounts
- Regular security updates

### Backup
- Database backup strategy
- Configuration backup
- Disaster recovery plan

### Monitoring
- Prometheus/Grafana stack
- Application performance monitoring
- Log aggregation (ELK stack)

### Updates
- Rolling updates for zero downtime
- Blue-green deployments
- Canary releases

## Customization

### Resource Requirements
Edit the resource requests/limits in deployment files:
```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

### Auto-scaling Behavior
Modify HPA configurations:
```yaml
behavior:
  scaleUp:
    stabilizationWindowSeconds: 60
    policies:
    - type: Percent
      value: 100
      periodSeconds: 15
```

### Ingress Configuration
Update ingress rules for your domain:
```yaml
rules:
- host: your-domain.com
  http:
    paths:
    - path: /
      pathType: Prefix
      backend:
        service:
          name: nlq-frontend-service
          port:
            number: 3000
```

## Cleanup

To remove the entire system:
```bash
kubectl delete namespace nlq-system
```

Or remove individual components:
```bash
kubectl delete -f backend-deployment.yaml
kubectl delete -f frontend-deployment.yaml
kubectl delete -f postgres-deployment.yaml
```
