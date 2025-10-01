#!/bin/bash

# Minikube Setup Script for NLQ Application
# This script sets up Minikube for local development

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

print_status "Setting up Minikube for NLQ Application..."

# Check if Minikube is installed
if ! command -v minikube &> /dev/null; then
    print_error "Minikube is not installed. Please install Minikube first."
    print_status "Install instructions: https://minikube.sigs.k8s.io/docs/start/"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    print_error "Docker is not running. Please start Docker first."
    exit 1
fi

# Start Minikube
print_status "Starting Minikube..."
minikube start

# Enable ingress addon
print_status "Enabling ingress addon..."
minikube addons enable ingress

# Set Docker environment to use Minikube's Docker daemon
print_status "Configuring Docker to use Minikube's Docker daemon..."
eval $(minikube docker-env)

print_success "Minikube setup completed!"
echo ""
print_status "Next steps:"
print_status "1. In another terminal, run: minikube tunnel"
print_status "2. Then run: ./deploy.sh deploy"
echo ""
print_warning "Important: Keep 'minikube tunnel' running in a separate terminal!"
print_status "This is required for LoadBalancer services to work in Minikube."
