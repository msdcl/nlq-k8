# NLQ Kubernetes Deployment Guide for AWS EKS

This guide will help you deploy the NLQ application on AWS EKS with nginx ingress using your custom domains:
- Backend: `avirat-empire-api.store`
- Frontend: `nlq-ui.shop`

## Prerequisites

1. **AWS EKS cluster** running (1.24+ recommended)
2. **kubectl** configured to access your EKS cluster
3. **AWS CLI** configured with appropriate permissions
4. **Docker images** built and pushed to ECR or your container registry
5. **Domain DNS** pointing to your EKS cluster's ingress controller
6. **nginx-ingress-controller** installed in your cluster
7. **cert-manager** installed for SSL certificates

## Step 1: Install Required Components

### Install nginx-ingress-controller for EKS
```bash
# Install nginx-ingress-controller with AWS Load Balancer Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/aws/deploy.yaml

# Apply the EKS-optimized service configuration
kubectl apply -f nginx-ingress-controller.yaml
```

### Install cert-manager
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
```

## Step 2: Configure DNS

Point your domains to your EKS cluster's Network Load Balancer:

```bash
# Get the external hostname of your nginx-ingress-controller
kubectl get svc -n ingress-nginx

# The service will show an EXTERNAL-IP (hostname) like:
# a1234567890abcdef-1234567890.us-west-2.elb.amazonaws.com

# Add these DNS records in your domain provider:
# avirat-empire-api.store -> <EXTERNAL-HOSTNAME>
# nlq-ui.shop -> <EXTERNAL-HOSTNAME>
```

### Alternative: Use Route 53 (Recommended for AWS)
If your domains are managed by Route 53:
```bash
# Get the load balancer hostname
LB_HOSTNAME=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Create Route 53 records (replace with your hosted zone ID)
aws route53 change-resource-record-sets --hosted-zone-id Z1234567890 --change-batch '{
  "Changes": [{
    "Action": "CREATE",
    "ResourceRecordSet": {
      "Name": "avirat-empire-api.store",
      "Type": "CNAME",
      "TTL": 300,
      "ResourceRecords": [{"Value": "'$LB_HOSTNAME'"}]
    }
  }]
}'
```

## Step 3: Update Configuration

### Update cluster-issuer.yaml
Edit `cluster-issuer.yaml` and replace the email with your actual email:
```yaml
spec:
  acme:
    email: m.chauhankk@gmail.com  # Replace this
```

### Update secret.yaml
Edit `secret.yaml` and replace the base64 encoded values with your actual secrets:
```bash
# Generate base64 encoded values
echo -n "your-db-password" | base64
echo -n "your-gemini-api-key" | base64
echo -n "your-jwt-secret" | base64
```

### Update image references
Edit the deployment files to use your actual container registry:
- `backend-deployment.yaml`: Update the image URL
- `frontend-deployment.yaml`: Update the image URL

## Step 4: Deploy the Application

### Create namespace and basic resources
```bash
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml
```

### Deploy cert-manager cluster issuer
```bash
kubectl apply -f cluster-issuer.yaml
```

### Deploy EKS-optimized storage class
```bash
kubectl apply -f gp2-csi.yaml  # Now uses gp3 with optimized settings
```

### Deploy PostgreSQL
```bash
kubectl apply -f postgres-deployment.yaml
```

### Wait for PostgreSQL to be ready
```bash
kubectl wait --for=condition=ready pod -l app=postgres -n nlq-system --timeout=300s
```

### Deploy backend and frontend
```bash
kubectl apply -f backend-deployment.yaml
kubectl apply -f frontend-deployment.yaml
```

### Deploy ingress
```bash
kubectl apply -f ingress.yaml
```

## Step 5: Verify Deployment

### Check all pods are running
```bash
kubectl get pods -n nlq-system
```

### Check services
```bash
kubectl get svc -n nlq-system
```

### Check ingress
```bash
kubectl get ingress -n nlq-system
```

### Check certificate status
```bash
kubectl get certificate -n nlq-system
kubectl describe certificate nlq-tls-secret -n nlq-system
```

## Step 6: Test the Application

### Test backend health
```bash
curl -k https://avirat-empire-api.store/health
```

### Test frontend
Open your browser and navigate to: `https://nlq-ui.shop`

## Troubleshooting

### Check pod logs
```bash
# Backend logs
kubectl logs -f deployment/nlq-backend -n nlq-system

# Frontend logs
kubectl logs -f deployment/nlq-frontend -n nlq-system

# PostgreSQL logs
kubectl logs -f deployment/postgres -n nlq-system
```

### Check ingress controller logs
```bash
kubectl logs -f deployment/ingress-nginx-controller -n ingress-nginx
```

### Check certificate issues
```bash
kubectl describe certificate nlq-tls-secret -n nlq-system
kubectl get certificaterequests -n nlq-system
kubectl get challenges -n nlq-system
```

### EKS-Specific Troubleshooting

#### Check Load Balancer Status
```bash
# Check if the NLB is created and healthy
aws elbv2 describe-load-balancers --names k8s-ingressn-ingressn

# Check target group health
aws elbv2 describe-target-groups --names k8s-ingressn-ingressn
aws elbv2 describe-target-health --target-group-arn <TARGET-GROUP-ARN>
```

#### Check EKS Node Group
```bash
# Verify node group status
aws eks describe-nodegroup --cluster-name <YOUR-CLUSTER-NAME> --nodegroup-name <YOUR-NODEGROUP-NAME>

# Check node capacity
kubectl get nodes
kubectl describe nodes
```

#### Check EBS CSI Driver
```bash
# Verify EBS CSI driver is running
kubectl get pods -n kube-system | grep ebs-csi

# Check PVC status
kubectl get pvc -n nlq-system
kubectl describe pvc postgres-pvc -n nlq-system
```

### Common Issues

1. **Certificate not issued**: Check DNS propagation and cert-manager logs
2. **Backend not accessible**: Verify CORS settings and service connectivity
3. **Database connection issues**: Check PostgreSQL pod status and credentials
4. **Image pull errors**: Verify ECR permissions and image URLs
5. **Load Balancer not accessible**: Check security groups and node group configuration
6. **Storage issues**: Verify EBS CSI driver and storage class configuration

## Scaling

The deployments include HorizontalPodAutoscaler (HPA) for automatic scaling:
- Backend: 2-8 replicas based on CPU (60%) and memory (70%)
- Frontend: 2-8 replicas based on CPU (70%) and memory (80%)

## Monitoring

### Check resource usage
```bash
kubectl top pods -n nlq-system
kubectl top nodes
```

### Check HPA status
```bash
kubectl get hpa -n nlq-system
```

## Cleanup

To remove the entire deployment:
```bash
kubectl delete namespace nlq-system
```

## Security Notes

1. **Secrets**: Ensure all secrets are properly base64 encoded
2. **Network Policies**: Consider implementing network policies for additional security
3. **RBAC**: Review and implement proper RBAC policies
4. **Image Security**: Use trusted base images and scan for vulnerabilities
5. **SSL/TLS**: Certificates are automatically managed by cert-manager
6. **EKS Security**: 
   - Enable EKS cluster logging
   - Use IAM roles for service accounts (IRSA)
   - Enable Pod Security Standards
   - Configure VPC security groups properly
   - Use ECR for container image storage

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Kubernetes and nginx-ingress documentation
3. Check application logs for specific error messages
