# NLQ Kubernetes Deployment Guide

## 🚀 Quick Start

### Prerequisites
- Kubernetes cluster (EKS, GKE, or local)
- kubectl configured
- Docker image pushed to ECR: `481665127661.dkr.ecr.ap-south-1.amazonaws.com/nlq-backend:latest`

### Deploy Everything
```bash
cd k8s
./deploy.sh
```

## 📁 File Structure

```
k8s/
├── namespace.yaml              # Namespace definition
├── nlq-config.yaml            # ConfigMap and Secrets
├── postgres-deployment.yaml   # PostgreSQL database
├── backend-deployment.yaml    # NLQ backend application
├── ingress.yaml              # Ingress configuration
├── deploy.sh                 # Deployment script
├── init-db.sh               # Database initialization
└── README.md                # This file
```

## 🗄️ Database Setup

### PostgreSQL Configuration
- **Image**: `postgres:15-alpine` (lightweight)
- **Storage**: 10Gi persistent volume
- **Resources**: 256Mi-512Mi RAM, 100m-500m CPU
- **Extensions**: `vector`, `pg_trgm` for AI features

### Database Initialization
```bash
# Run database initialization
kubectl exec -it deployment/postgres -n nlq-system -- /bin/bash
# Then run the init-db.sh script
```

## 🌐 Service Exposure

### Development
- **Frontend**: `http://nlq.local/`
- **Backend API**: `http://nlq.local/api/*`
- **Direct Backend**: `http://api.nlq.local/`

### Production
- **Frontend**: `https://nlq-ui.shop/`
- **Backend API**: `https://avirat-empire-api.store/`
- **Direct Backend**: `https://avirat-empire-api.store/`

## 🔧 Configuration

### Environment Variables
Update `nlq-config.yaml` with your settings:
- Database credentials
- Gemini API key
- CORS origins
- Log levels

### Secrets
Update base64 encoded values in `nlq-config.yaml`:
```bash
echo -n "your-password" | base64
```

## 📊 Monitoring

### Check Status
```bash
# All pods
kubectl get pods -n nlq-system

# Services
kubectl get services -n nlq-system

# Ingress
kubectl get ingress -n nlq-system

# HPA status
kubectl get hpa -n nlq-system
```

### View Logs
```bash
# Backend logs
kubectl logs -f deployment/nlq-backend -n nlq-system

# PostgreSQL logs
kubectl logs -f deployment/postgres -n nlq-system
```

## 🔄 Scaling

### Manual Scaling
```bash
# Scale backend
kubectl scale deployment nlq-backend --replicas=3 -n nlq-system

# Scale PostgreSQL (not recommended for production)
kubectl scale deployment postgres --replicas=1 -n nlq-system
```

### Auto Scaling
HPA is configured to scale based on:
- CPU: 60% utilization
- Memory: 70% utilization
- Min replicas: 2
- Max replicas: 8

## 🛠️ Troubleshooting

### Common Issues

1. **Pod not starting**
   ```bash
   kubectl describe pod <pod-name> -n nlq-system
   kubectl logs <pod-name> -n nlq-system
   ```

2. **Database connection issues**
   ```bash
   kubectl exec -it deployment/postgres -n nlq-system -- psql -U nlq_user -d nlq_database
   ```

3. **Ingress not working**
   ```bash
   kubectl get ingress -n nlq-system
   kubectl describe ingress nlq-ingress -n nlq-system
   ```

### Port Forwarding (for testing)
```bash
# Backend
kubectl port-forward service/nlq-backend-service 3001:3001 -n nlq-system

# PostgreSQL
kubectl port-forward service/postgres-service 5432:5432 -n nlq-system
```

## 💰 Cost Optimization

### Resource Limits
- **PostgreSQL**: 256Mi-512Mi RAM, 100m-500m CPU
- **Backend**: 512Mi-2Gi RAM, 200m-1000m CPU
- **Storage**: 10Gi for database

### Scaling Policies
- Conservative scaling to avoid unnecessary costs
- Single PostgreSQL replica for cost efficiency
- HPA with reasonable thresholds

## 🔒 Security Notes

- Non-root containers
- Secrets in Kubernetes secrets
- Network policies (can be added)
- TLS termination at ingress
- Rate limiting enabled

## 🗑️ Cleanup

```bash
# Delete everything
kubectl delete namespace nlq-system

# Or delete individual resources
kubectl delete -f backend-deployment.yaml
kubectl delete -f postgres-deployment.yaml
kubectl delete -f nlq-config.yaml
kubectl delete -f namespace.yaml
```