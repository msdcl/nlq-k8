# AWS VM Deployment Guide

## Prerequisites

1. **AWS EC2 Instance** with K3s installed
2. **Domain Configuration**:
   - `nlq-ui.shop` → Your AWS VM IP
   - `avirat-empire-api.store` → Your AWS VM IP
3. **SSL Certificates** (optional but recommended)

## Deployment Steps

### 1. Prepare Your AWS VM

```bash
# Install K3s (if not already installed)
curl -sfL https://get.k3s.io | sh -

# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Wait for ingress controller to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx --timeout=300s
```

### 2. Update Configuration Files

The following files are already configured for production:

- **ConfigMap**: `REACT_APP_API_URL: "https://avirat-empire-api.store/api"`
- **Ingress**: Routes for both domains with NGINX ingress class
- **Deploy Script**: Auto-detects production environment

### 3. Deploy the Application

```bash
# Navigate to k8s directory
cd k8s

# Deploy everything
./deploy.sh deploy
```

The script will:
- Build images with production API URLs
- Deploy all components
- Configure ingress for production
- Verify health checks

### 4. Configure DNS

Point your domains to your AWS VM's public IP:

```
nlq-ui.shop          A    YOUR_AWS_VM_IP
avirat-empire-api.store A    YOUR_AWS_VM_IP
```

### 5. SSL Configuration (Optional)

To enable HTTPS, create a TLS secret:

```bash
# Create TLS secret (replace with your certificates)
kubectl create secret tls nlq-tls-secret \
  --cert=path/to/your/cert.pem \
  --key=path/to/your/key.pem \
  -n nlq-app

# Uncomment TLS section in ingress.yaml
```

## Access Your Application

After deployment:

- **Frontend**: https://nlq-ui.shop
- **Backend API**: https://avirat-empire-api.store
- **Health Check**: https://nlq-ui.shop/api/health

## Troubleshooting

### Check Deployment Status
```bash
./deploy.sh status
```

### Verify Health
```bash
./deploy.sh health
```

### Check Ingress
```bash
kubectl get ingress -n nlq-app
kubectl describe ingress nlq-ingress -n nlq-app
```

### Check External IP
```bash
kubectl get service ingress-nginx-controller -n ingress-nginx
```

## Production Considerations

1. **Resource Limits**: Adjust CPU/memory limits in deployment files
2. **Replicas**: Increase replica count for high availability
3. **Monitoring**: Add monitoring and logging
4. **Backup**: Set up database backups
5. **Security**: Review security policies and network policies

## Environment Variables

Update these in `k8s/secret.yaml` for production:

- `DB_PASSWORD`: Strong database password
- `GEMINI_API_KEY`: Your actual Gemini API key
- `JWT_SECRET`: Strong JWT secret

## Scaling

To scale your application:

```bash
# Scale backend
kubectl scale deployment nlq-backend --replicas=3 -n nlq-app

# Scale frontend
kubectl scale deployment nlq-frontend --replicas=2 -n nlq-app
```
