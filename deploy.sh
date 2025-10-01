#!/bin/bash

# NLQ Application Kubernetes Deployment Script
# This script deploys the NLQ application to a K3s cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="nlq-app"
REGISTRY=""  # Docker Desktop uses local images directly
BACKEND_IMAGE="nlq-backend"
FRONTEND_IMAGE="nlq-frontend"
TAG="latest"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    print_success "kubectl is available"
}

# Function to check if K3s cluster is accessible
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    print_success "Connected to Kubernetes cluster"
}

# Function to build Docker images
build_images() {
    CLUSTER_TYPE=$(detect_cluster)
    
    if [ "$CLUSTER_TYPE" = "docker-desktop" ]; then
        print_status "Building Docker images for Docker Desktop..."
        
        # Build backend image
        print_status "Building backend image..."
        docker build -t ${BACKEND_IMAGE}:${TAG} ./backend/
        
        # Build frontend image with same-origin API URL for proper proxy routing
        print_status "Building frontend image with same-origin API configuration..."
        docker build --build-arg REACT_APP_API_URL=/api -t ${FRONTEND_IMAGE}:${TAG} ./frontend/
        
        print_success "Images built successfully for Docker Desktop"
        print_warning "Note: Images are built locally and available to Docker Desktop Kubernetes"
    else
        print_status "Building Docker images for production deployment..."
        
        # Build backend image
        print_status "Building backend image..."
        docker build -t ${BACKEND_IMAGE}:${TAG} ./backend/
        
        # Build frontend image with production API URL
        print_status "Building frontend image with production API configuration..."
        docker build --build-arg REACT_APP_API_URL=https://avirat-empire-api.store/api -t ${FRONTEND_IMAGE}:${TAG} ./frontend/
        
        print_success "Images built successfully for production"
        print_warning "Note: Make sure to push images to your container registry for production deployment"
    fi
}

# Function to update image references in deployment files
update_image_references() {
    print_status "Image references already configured for local Minikube deployment"
    print_status "Backend: ${REGISTRY}/${BACKEND_IMAGE}:${TAG}"
    print_status "Frontend: ${REGISTRY}/${FRONTEND_IMAGE}:${TAG}"
}

# Function to deploy namespace
deploy_namespace() {
    print_status "Deploying namespace..."
    kubectl apply -f namespace.yaml
    print_success "Namespace deployed"
}

# Function to deploy secrets and configmaps
deploy_config() {
    print_status "Deploying secrets and configmaps..."
    kubectl apply -f secret.yaml
    kubectl apply -f configmap.yaml
    
    # Ensure ConfigMap has correct API URL based on cluster type
    CLUSTER_TYPE=$(detect_cluster)
    if [ "$CLUSTER_TYPE" = "docker-desktop" ]; then
        print_status "Ensuring ConfigMap has correct API URL for local development..."
        kubectl patch configmap nlq-config -n ${NAMESPACE} --type='json' -p='[{"op": "replace", "path": "/data/REACT_APP_API_URL", "value": "/api"}]' 2>/dev/null || true
    else
        print_status "Ensuring ConfigMap has correct API URL for production..."
        kubectl patch configmap nlq-config -n ${NAMESPACE} --type='json' -p='[{"op": "replace", "path": "/data/REACT_APP_API_URL", "value": "https://avirat-empire-api.store/api"}]' 2>/dev/null || true
    fi
    
    print_success "Secrets and configmaps deployed"
}

# Function to cleanup old deployments
cleanup_old_deployments() {
    print_status "Cleaning up any existing deployments..."
    kubectl delete deployment postgres -n ${NAMESPACE} --ignore-not-found=true
    kubectl delete deployment nlq-backend -n ${NAMESPACE} --ignore-not-found=true
    kubectl delete deployment nlq-frontend -n ${NAMESPACE} --ignore-not-found=true
    kubectl delete pvc postgres-pvc -n ${NAMESPACE} --ignore-not-found=true
    print_success "Old deployments cleaned up"
}

# Function to deploy PostgreSQL
deploy_postgres() {
    print_status "Deploying PostgreSQL..."
    kubectl apply -f postgres-deployment.yaml
    
    # Wait for PostgreSQL to be ready
    print_status "Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=ready pod -l app=postgres -n ${NAMESPACE} --timeout=300s
    print_success "PostgreSQL deployed and ready"
}

# Function to deploy backend
deploy_backend() {
    print_status "Deploying backend..."
    kubectl apply -f backend-deployment.yaml
    
    # Wait for backend to be ready
    print_status "Waiting for backend to be ready..."
    kubectl wait --for=condition=ready pod -l app=nlq-backend -n ${NAMESPACE} --timeout=300s
    
    # Verify backend service has endpoints
    print_status "Verifying backend service endpoints..."
    sleep 5
    ENDPOINTS=$(kubectl get endpoints nlq-backend-service -n ${NAMESPACE} -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null)
    if [ -z "$ENDPOINTS" ]; then
        print_warning "Backend service has no endpoints, checking pod status..."
        kubectl get pods -n ${NAMESPACE} -l app=nlq-backend
        print_error "Backend service is not ready. Check pod logs for issues."
        return 1
    fi
    
    print_success "Backend deployed and ready with endpoints: $ENDPOINTS"
}

# Function to deploy frontend
deploy_frontend() {
    print_status "Deploying frontend..."
    kubectl apply -f frontend-deployment.yaml
    
    # Wait for frontend to be ready
    print_status "Waiting for frontend to be ready..."
    kubectl wait --for=condition=ready pod -l app=nlq-frontend -n ${NAMESPACE} --timeout=300s
    
    # Restart frontend to pick up ConfigMap changes
    print_status "Restarting frontend to pick up ConfigMap changes..."
    kubectl rollout restart deployment/nlq-frontend -n ${NAMESPACE}
    kubectl rollout status deployment/nlq-frontend -n ${NAMESPACE}
    
    print_success "Frontend deployed and ready"
}

# Function to deploy NGINX ingress controller
deploy_ingress_controller() {
    print_status "Deploying NGINX Ingress Controller..."
    kubectl apply -f nginx-ingress-controller.yaml
    
    # Wait for ingress controller to be ready
    print_status "Waiting for NGINX Ingress Controller to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx --timeout=300s
    print_success "NGINX Ingress Controller deployed and ready"
}

# Function to deploy ingress
deploy_ingress() {
    print_status "Deploying ingress..."
    kubectl apply -f ingress.yaml
    print_success "Ingress deployed"
}

# Function to detect cluster type
detect_cluster() {
    if kubectl get nodes -o jsonpath='{.items[0].metadata.labels}' | grep -q "minikube"; then
        echo "minikube"
    elif kubectl get nodes -o jsonpath='{.items[0].metadata.labels}' | grep -q "k3s"; then
        echo "k3s"
    elif kubectl get nodes -o jsonpath='{.items[0].metadata.labels}' | grep -q "docker-desktop"; then
        echo "docker-desktop"
    else
        echo "unknown"
    fi
}

# Function to fix storage class for Docker Desktop
fix_storage_for_docker_desktop() {
    CLUSTER_TYPE=$(detect_cluster)
    if [ "$CLUSTER_TYPE" = "docker-desktop" ]; then
        print_status "Docker Desktop detected - using emptyDir for PostgreSQL storage"
        # The postgres-deployment.yaml is already configured for emptyDir
        return 0
    fi
}

# Function to fix image pull policy for local images
fix_image_pull_policy() {
    CLUSTER_TYPE=$(detect_cluster)
    if [ "$CLUSTER_TYPE" = "docker-desktop" ]; then
        print_status "Setting imagePullPolicy to Never for local Docker images"
        # Update deployment files to use Never policy for local images
        sed -i.bak 's/imagePullPolicy: IfNotPresent/imagePullPolicy: Never/g' backend-deployment.yaml
        sed -i.bak 's/imagePullPolicy: IfNotPresent/imagePullPolicy: Never/g' frontend-deployment.yaml
        print_success "Image pull policy updated for Docker Desktop"
    fi
}

# Function to fix database user in secrets
fix_database_secrets() {
    print_status "Ensuring correct database user in secrets..."
    # Check if DB_USER is correctly set to nlq_user
    CURRENT_DB_USER=$(kubectl get secret nlq-secrets -n ${NAMESPACE} -o jsonpath='{.data.DB_USER}' 2>/dev/null | base64 -d)
    if [ "$CURRENT_DB_USER" != "nlq_user" ]; then
        print_status "Fixing database user in secrets..."
        # Update the secret with correct base64 encoded nlq_user
        kubectl patch secret nlq-secrets -n ${NAMESPACE} --type='json' -p='[{"op": "replace", "path": "/data/DB_USER", "value": "bmxxX3VzZXI="}]'
        kubectl patch secret nlq-secrets -n ${NAMESPACE} --type='json' -p='[{"op": "replace", "path": "/data/VECTOR_DB_USER", "value": "bmxxX3VzZXI="}]'
        print_success "Database user fixed in secrets"
    fi
}

# Function to create required databases
create_databases() {
    print_status "Creating required databases..."
    
    # Wait for PostgreSQL to be ready
    kubectl wait --for=condition=ready pod -l app=postgres -n ${NAMESPACE} --timeout=60s
    
    # Get PostgreSQL pod name (find running pod)
    POSTGRES_POD=$(kubectl get pods -n ${NAMESPACE} -l app=postgres -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | awk 'NR==1{print}')
    
    if [ -z "$POSTGRES_POD" ]; then
        print_error "No running PostgreSQL pod found"
        return 1
    fi
    
    print_status "Using PostgreSQL pod: $POSTGRES_POD"
    
    # Create nlq_vectors database if it doesn't exist (using proper existence check)
    print_status "Checking if nlq_vectors database exists..."
    kubectl exec ${POSTGRES_POD} -n ${NAMESPACE} -- sh -c 'psql -U nlq_user -d nlq_database -tc "SELECT 1 FROM pg_database WHERE datname='\''nlq_vectors'\'';" | grep -q 1' || {
        print_status "Creating nlq_vectors database..."
        kubectl exec ${POSTGRES_POD} -n ${NAMESPACE} -- psql -U nlq_user -d nlq_database -c "CREATE DATABASE nlq_vectors;"
        print_success "nlq_vectors database created"
    }
    
    print_success "Database setup completed"
}

# Function to fix ingress based on cluster type
fix_ingress_for_cluster() {
    CLUSTER_TYPE=$(detect_cluster)
    if [ "$CLUSTER_TYPE" = "docker-desktop" ]; then
        print_status "Configuring ingress for Docker Desktop..."
        # Update ingress to use traefik instead of nginx
        sed -i.bak 's/kubernetes.io\/ingress.class: "nginx"/kubernetes.io\/ingress.class: "traefik"/g' ingress.yaml
        print_success "Ingress configured for Docker Desktop"
    else
        print_status "Configuring ingress for production (K3s/AWS)..."
        # Update ingress to use nginx for production
        sed -i.bak 's/kubernetes.io\/ingress.class: "traefik"/kubernetes.io\/ingress.class: "nginx"/g' ingress.yaml
        print_success "Ingress configured for production"
    fi
}

# Function to show deployment status
show_status() {
    print_status "Deployment Status:"
    echo ""
    
    print_status "Pods:"
    kubectl get pods -n ${NAMESPACE}
    echo ""
    
    print_status "Services:"
    kubectl get services -n ${NAMESPACE}
    echo ""
    
    print_status "Ingress:"
    kubectl get ingress -n ${NAMESPACE}
    echo ""
    
    print_status "NGINX Ingress Controller:"
    kubectl get pods -n ingress-nginx
    echo ""
    
    CLUSTER_TYPE=$(detect_cluster)
    
    if [ "$CLUSTER_TYPE" = "minikube" ]; then
        print_success "Minikube detected. Access your application:"
        print_success "Frontend: http://localhost (or http://$(minikube ip))"
        print_success "Backend API: http://localhost/api (or http://$(minikube ip)/api)"
        print_warning "Make sure to run: minikube tunnel (in another terminal)"
    elif [ "$CLUSTER_TYPE" = "docker-desktop" ]; then
        print_success "Docker Desktop detected. Access your application:"
        print_success "Frontend: http://localhost:8080"
        print_success "Backend API: http://localhost:3001"
        print_success "API via Frontend: http://localhost:8080/api/*"
    else
        # Production deployment (K3s/AWS)
        print_success "Production deployment detected. Access your application:"
        print_success "Frontend: https://nlq-ui.shop"
        print_success "Backend API: https://avirat-empire-api.store"
        
        # Get external IP for reference
        EXTERNAL_IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -n "$EXTERNAL_IP" ]; then
            print_success "External IP: ${EXTERNAL_IP}"
            print_warning "Make sure your domains point to this IP:"
            print_warning "  nlq-ui.shop -> ${EXTERNAL_IP}"
            print_warning "  avirat-empire-api.store -> ${EXTERNAL_IP}"
        else
            print_warning "External IP not yet assigned. Check with: kubectl get service ingress-nginx-controller -n ingress-nginx"
        fi
    fi
}

# Function to stop port forwarding
stop_port_forwarding() {
    print_status "Stopping port forwarding..."
    pkill -f "kubectl port-forward" 2>/dev/null || true
    print_success "Port forwarding stopped"
}

# Function to verify application health
verify_application_health() {
    print_status "Verifying application health..."
    
    # Start port forwarding for testing
    print_status "Setting up temporary port forwarding for health checks..."
    kubectl port-forward service/nlq-frontend-service 8080:80 -n ${NAMESPACE} > /dev/null 2>&1 &
    kubectl port-forward service/nlq-backend-service 3001:3001 -n ${NAMESPACE} > /dev/null 2>&1 &
    sleep 3
    
    # Test endpoints
    local health_checks_passed=0
    local total_checks=5
    
    print_status "Testing endpoints..."
    
    # Test 1: Frontend
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 | grep -q "200"; then
        print_success "✓ Frontend: http://localhost:8080"
        ((health_checks_passed++))
    else
        print_error "✗ Frontend: http://localhost:8080"
    fi
    
    # Test 2: Backend direct health
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:3001/health | grep -q "200"; then
        print_success "✓ Backend Health: http://localhost:3001/health"
        ((health_checks_passed++))
    else
        print_error "✗ Backend Health: http://localhost:3001/health"
    fi
    
    # Test 3: Frontend proxy /api/health
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/health | grep -q "200"; then
        print_success "✓ API Health: http://localhost:8080/api/health"
        ((health_checks_passed++))
    else
        print_error "✗ API Health: http://localhost:8080/api/health"
    fi
    
    # Test 4: Frontend proxy /api/nlq/health
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/nlq/health | grep -q "200"; then
        print_success "✓ NLQ Health: http://localhost:8080/api/nlq/health"
        ((health_checks_passed++))
    else
        print_error "✗ NLQ Health: http://localhost:8080/api/nlq/health"
    fi
    
    # Test 5: Dashboard API
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/dashboard/all | grep -q "200"; then
        print_success "✓ Dashboard API: http://localhost:8080/api/dashboard/all"
        ((health_checks_passed++))
    else
        print_error "✗ Dashboard API: http://localhost:8080/api/dashboard/all"
    fi
    
    # Stop temporary port forwarding
    pkill -f "kubectl port-forward" 2>/dev/null || true
    
    echo ""
    if [ $health_checks_passed -eq $total_checks ]; then
        print_success "All health checks passed! ($health_checks_passed/$total_checks)"
        return 0
    else
        print_warning "Some health checks failed ($health_checks_passed/$total_checks)"
        return 1
    fi
}

# Function to cleanup
cleanup() {
    print_status "Cleaning up deployment..."
    stop_port_forwarding
    kubectl delete -f ingress.yaml --ignore-not-found=true
    kubectl delete -f frontend-deployment.yaml --ignore-not-found=true
    kubectl delete -f backend-deployment.yaml --ignore-not-found=true
    kubectl delete -f postgres-deployment.yaml --ignore-not-found=true
    kubectl delete -f configmap.yaml --ignore-not-found=true
    kubectl delete -f secret.yaml --ignore-not-found=true
    kubectl delete -f namespace.yaml --ignore-not-found=true
    print_success "Cleanup completed"
}

# Main deployment function
deploy() {
    print_status "Starting NLQ application deployment..."
    
    check_kubectl
    check_cluster
    
    # Ask user if they want to build images
    read -p "Do you want to build Docker images? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        build_images
    else
        print_warning "Skipping image build. Make sure images are available locally."
    fi
    
    deploy_namespace
    deploy_config
    fix_storage_for_docker_desktop
    fix_image_pull_policy
    fix_ingress_for_cluster
    cleanup_old_deployments
    deploy_postgres
    fix_database_secrets
    create_databases
    deploy_backend
    deploy_frontend
    deploy_ingress
    
    # Verify application health
    if verify_application_health; then
        print_success "Deployment completed successfully!"
    else
        print_warning "Deployment completed but some health checks failed. Check the logs above."
    fi
    
    show_status
    
    # Setup port forwarding for Docker Desktop
    CLUSTER_TYPE=$(detect_cluster)
    if [ "$CLUSTER_TYPE" = "docker-desktop" ]; then
        print_status "Setting up port forwarding for Docker Desktop..."
        print_status "Frontend: http://localhost:8080"
        print_status "Backend: http://localhost:3001"
        print_warning "Port forwarding will run in background. Use './deploy.sh stop-ports' to stop."
        
        # Start port forwarding in background
        kubectl port-forward service/nlq-frontend-service 8080:80 -n ${NAMESPACE} > /dev/null 2>&1 &
        kubectl port-forward service/nlq-backend-service 3001:3001 -n ${NAMESPACE} > /dev/null 2>&1 &
        
        print_success "Port forwarding started!"
        print_status "Access your application at:"
        print_status "  Frontend: http://localhost:8080"
        print_status "  Backend API: http://localhost:3001"
        print_status "  API via Frontend: http://localhost:8080/api/*"
    fi
}

# Parse command line arguments
case "${1:-deploy}" in
    deploy)
        deploy
        ;;
    status)
        show_status
        ;;
    health)
        verify_application_health
        ;;
    cleanup)
        cleanup
        ;;
    stop-ports)
        stop_port_forwarding
        ;;
    *)
        echo "Usage: $0 {deploy|status|health|cleanup|stop-ports}"
        echo "  deploy     - Deploy the application (default)"
        echo "  status     - Show deployment status"
        echo "  health     - Verify application health"
        echo "  cleanup    - Remove all resources"
        echo "  stop-ports - Stop port forwarding"
        exit 1
        ;;
esac
