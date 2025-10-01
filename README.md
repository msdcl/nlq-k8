# NLQ Application Kubernetes Deployment

This directory contains Kubernetes manifests and deployment scripts for the NLQ (Natural Language Query) application.

## Architecture

The deployment includes:
- **Frontend**: React application served by NGINX (Domain: `nlq-ui.shop`)
- **Backend**: Node.js API server (Domain: `avirat-empire-api.store`)
- **Database**: PostgreSQL with pgvector extension
- **Ingress**: NGINX Ingress Controller for external access

## Prerequisites

1. **Kubernetes Cluster**: 
   - **Local Development**: Minikube
   - **Production**: K3s on VM
2. **kubectl**: Install and configure kubectl to access your cluster
3. **Docker**: For building container images
4. **Container Registry**: Access to a container registry (Docker Hub, AWS ECR, etc.)

### For Minikube (Local Development)
```bash
# Start Minikube
minikube start

# Enable ingress addon
minikube addons enable ingress

# Start tunnel (required for LoadBalancer services)
minikube tunnel
```

### For K3s (Production)
```bash
# Install K3s
curl -sfL https://get.k3s.io | sh -

# Configure kubectl
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER ~/.kube/config
```

## Quick Start

### 1. Configure Environment

Before deploying, update the following files with your specific configuration:

#### Update `secret.yaml`
Replace the base64 encoded values with your actual secrets:
```bash
# Generate base64 encoded values
echo -n "your_db_password" | base64
echo -n "your_gemini_api_key" | base64
echo -n "your_jwt_secret" | base64
```

#### Update `configmap.yaml`
- Frontend URL: `https://nlq-ui.shop` (already configured)
- Backend API URL: `https://avirat-empire-api.store` (already configured)

#### Update `ingress.yaml` and `backend-ingress.yaml`
- Frontend domain: `nlq-ui.shop` (already configured)
- Backend domain: `avirat-empire-api.store` (already configured)
- Configure SSL/TLS if needed

#### Update `deploy.sh`
- Set your container registry URL
- Update image names if different

### 2. Deploy the Application

#### Option A: Using the deployment script (Recommended)
```bash
# Make the script executable
chmod +x deploy.sh

# Deploy everything
./deploy.sh deploy

# Check status
./deploy.sh status

# Clean up (if needed)
./deploy.sh cleanup
```

#### Option B: Using kubectl directly
```bash
# Deploy in order
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml
kubectl apply -f postgres-deployment.yaml
kubectl apply -f backend-deployment.yaml
kubectl apply -f frontend-deployment.yaml
kubectl apply -f nginx-ingress-controller.yaml
kubectl apply -f ingress.yaml
```

#### Option C: Using Kustomize
```bash
kubectl apply -k .
```

### 3. Access the Application

After deployment, get the external IP:
```bash
kubectl get service ingress-nginx-controller -n ingress-nginx
```

Access your applications:

**For Minikube (Local Development):**
- **Frontend**: `http://localhost` (or `http://$(minikube ip)`)
- **Backend API**: `http://localhost/api` (or `http://$(minikube ip)/api`)
- **Note**: Make sure `minikube tunnel` is running

**For K3s (Production):**
- **Frontend**: `https://nlq-ui.shop` (or `http://<EXTERNAL_IP>`)
- **Backend API**: `https://avirat-empire-api.store` (or `http://<EXTERNAL_IP>/api`)

## File Structure

```
k8s/
├── namespace.yaml                 # Application namespace
├── configmap.yaml                # Non-sensitive configuration
├── secret.yaml                   # Sensitive configuration (secrets)
├── postgres-deployment.yaml      # PostgreSQL database
├── backend-deployment.yaml       # Node.js backend API
├── frontend-deployment.yaml      # React frontend
├── nginx-ingress-controller.yaml # NGINX Ingress Controller
├── ingress.yaml                  # Combined ingress (frontend + backend)
├── kustomization.yaml           # Kustomize configuration
├── deploy.sh                    # Deployment script
└── README.md                    # This file
```

## Configuration Details

### Resource Limits
- **PostgreSQL**: 256Mi-512Mi memory, 250m-500m CPU
- **Backend**: 256Mi-512Mi memory, 250m-500m CPU
- **Frontend**: 128Mi-256Mi memory, 100m-200m CPU
- **NGINX Ingress**: 90Mi-200Mi memory, 100m-200m CPU

### Storage
- PostgreSQL uses a 10Gi PersistentVolumeClaim
- Uses default storage class (works for both Minikube and K3s)

### Networking
- All services use ClusterIP (internal communication)
- NGINX Ingress Controller uses LoadBalancer for external access
- CORS enabled for cross-origin requests
- Separate ingress for frontend and backend domains

## Single Ingress Configuration

We use a single ingress file that handles both domains:
- **Frontend**: `nlq-ui.shop` (production) / `localhost` (local)
- **Backend**: `avirat-empire-api.store` (production) / `localhost/api` (local)

**Benefits of single ingress:**
- ✅ Simpler configuration management
- ✅ Single file to maintain
- ✅ Works for both local development and production
- ✅ Unified CORS and security policies

## Monitoring and Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n nlq-app
kubectl describe pod <pod-name> -n nlq-app
```

### Check Logs
```bash
# Backend logs
kubectl logs -f deployment/nlq-backend -n nlq-app

# Frontend logs
kubectl logs -f deployment/nlq-frontend -n nlq-app

# PostgreSQL logs
kubectl logs -f deployment/postgres -n nlq-app
```

### Check Services
```bash
kubectl get services -n nlq-app
kubectl get ingress -n nlq-app
```

### Port Forward for Testing
```bash
# Test backend directly
kubectl port-forward service/nlq-backend-service 3001:3001 -n nlq-app

# Test frontend directly
kubectl port-forward service/nlq-frontend-service 8080:80 -n nlq-app
```

## Security Considerations

1. **Secrets**: All sensitive data is stored in Kubernetes secrets
2. **Non-root containers**: All containers run as non-root users
3. **Resource limits**: All containers have resource limits
4. **Health checks**: All services have liveness and readiness probes
5. **Network policies**: Consider implementing network policies for additional security

## Scaling

### Horizontal Pod Autoscaling (HPA)
To enable auto-scaling, create an HPA resource:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nlq-backend-hpa
  namespace: nlq-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nlq-backend
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Manual Scaling
```bash
# Scale backend
kubectl scale deployment nlq-backend --replicas=3 -n nlq-app

# Scale frontend
kubectl scale deployment nlq-frontend --replicas=3 -n nlq-app
```

## Backup and Recovery

### Database Backup
```bash
# Create backup
kubectl exec -it deployment/postgres -n nlq-app -- pg_dump -U nlq_user nlq_database > backup.sql

# Restore backup
kubectl exec -i deployment/postgres -n nlq-app -- psql -U nlq_user nlq_database < backup.sql
```

## Cost Optimization

This deployment is optimized for minimal cost:
- Uses K3s (lightweight Kubernetes)
- Single-node PostgreSQL (can be externalized)
- Resource limits prevent overconsumption
- Local storage for development/testing

For production, consider:
- External managed database (AWS RDS, Google Cloud SQL)
- Multi-AZ deployment for high availability
- Persistent volumes with appropriate storage classes
- Monitoring and alerting setup

## Support

For issues or questions:
1. Check the logs using the commands above
2. Verify all secrets and configmaps are properly set
3. Ensure your container images are accessible
4. Check network connectivity between services
