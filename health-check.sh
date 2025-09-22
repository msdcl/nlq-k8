#!/bin/bash

# Health check script for NLQ deployment
# This script verifies that all components are running correctly

set -e

echo "🏥 NLQ Health Check"
echo "=================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check namespace
echo "📋 Checking namespace..."
if kubectl get namespace nlq-system &> /dev/null; then
    print_status "Namespace 'nlq-system' exists"
else
    print_error "Namespace 'nlq-system' not found"
    exit 1
fi

# Check pods
echo "🐳 Checking pods..."
pods=$(kubectl get pods -n nlq-system --no-headers | wc -l)
if [ $pods -gt 0 ]; then
    print_status "Found $pods pod(s) in namespace"
    kubectl get pods -n nlq-system
else
    print_error "No pods found in namespace"
    exit 1
fi

# Check PostgreSQL
echo "🗄️ Checking PostgreSQL..."
if kubectl get deployment postgres -n nlq-system &> /dev/null; then
    postgres_ready=$(kubectl get deployment postgres -n nlq-system -o jsonpath='{.status.readyReplicas}')
    if [ "$postgres_ready" = "1" ]; then
        print_status "PostgreSQL is running"
    else
        print_warning "PostgreSQL is not ready yet"
    fi
else
    print_error "PostgreSQL deployment not found"
fi

# Check Backend
echo "🚀 Checking Backend..."
if kubectl get deployment nlq-backend -n nlq-system &> /dev/null; then
    backend_ready=$(kubectl get deployment nlq-backend -n nlq-system -o jsonpath='{.status.readyReplicas}')
    if [ "$backend_ready" -gt 0 ]; then
        print_status "Backend is running ($backend_ready replicas)"
    else
        print_warning "Backend is not ready yet"
    fi
else
    print_error "Backend deployment not found"
fi

# Check services
echo "🌐 Checking services..."
services=$(kubectl get services -n nlq-system --no-headers | wc -l)
if [ $services -gt 0 ]; then
    print_status "Found $services service(s)"
    kubectl get services -n nlq-system
else
    print_error "No services found"
fi

# Check ingress
echo "🔗 Checking ingress..."
if kubectl get ingress -n nlq-system &> /dev/null; then
    print_status "Ingress is configured"
    kubectl get ingress -n nlq-system
else
    print_warning "No ingress found"
fi

# Test backend health endpoint
echo "💓 Testing backend health..."
backend_pod=$(kubectl get pods -n nlq-system -l app=nlq-backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$backend_pod" ]; then
    if kubectl exec -n nlq-system $backend_pod -- curl -s http://localhost:3001/health &> /dev/null; then
        print_status "Backend health check passed"
    else
        print_warning "Backend health check failed"
    fi
else
    print_warning "No backend pod found for health check"
fi

# Test database connection
echo "🔌 Testing database connection..."
postgres_pod=$(kubectl get pods -n nlq-system -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$postgres_pod" ]; then
    if kubectl exec -n nlq-system $postgres_pod -- pg_isready -U nlq_user -d nlq_database &> /dev/null; then
        print_status "Database connection successful"
    else
        print_warning "Database connection failed"
    fi
else
    print_warning "No PostgreSQL pod found for connection test"
fi

echo ""
echo "🎉 Health check completed!"
echo ""
echo "📊 Summary:"
echo "  - Namespace: nlq-system"
echo "  - Pods: $pods"
echo "  - Services: $services"
echo ""
echo "🔧 Useful commands:"
echo "  kubectl get pods -n nlq-system"
echo "  kubectl logs -f deployment/nlq-backend -n nlq-system"
echo "  kubectl port-forward service/nlq-backend-service 3001:3001 -n nlq-system"
echo ""
echo "🌐 Access URLs:"
echo "  Frontend: https://nlq-ui.shop"
echo "  Backend API: https://avirat-empire-api.store"
