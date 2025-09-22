#!/bin/bash
set -e

NAMESPACE="nlq-system"

echo "🚀 Starting deployment to namespace: $NAMESPACE"

# Step 1: Create namespace
echo "📦 Creating namespace..."
kubectl apply -f namespace.yaml

# Step 2: Apply ConfigMaps & Secrets
echo "⚙️ Applying configuration..."
kubectl apply -f nlq-config.yaml -n $NAMESPACE
kubectl apply -f configmap.yaml -n $NAMESPACE
kubectl apply -f secret.yaml -n $NAMESPACE

# Step 3: Deploy Postgres
echo "🐘 Deploying Postgres..."
kubectl apply -f postgres-deployment.yaml -n $NAMESPACE

echo "⏳ Waiting for Postgres to become ready..."
kubectl wait --for=condition=available --timeout=300s deployment/postgres -n $NAMESPACE

# Step 4: Deploy Backend
echo "🖥️ Deploying NLQ Backend..."
kubectl apply -f backend-deployment.yaml -n $NAMESPACE

echo "⏳ Waiting for Backend to become ready..."
kubectl wait --for=condition=available --timeout=300s deployment/nlq-backend -n $NAMESPACE

# Step 5: Deploy Frontend
echo "🌐 Deploying NLQ Frontend..."
kubectl apply -f frontend-deployment.yaml -n $NAMESPACE

echo "⏳ Waiting for Frontend to become ready..."
kubectl wait --for=condition=available --timeout=300s deployment/nlq-frontend -n $NAMESPACE

# Step 6: Apply Ingress
echo "🌍 Applying Ingress..."
kubectl apply -f common-ingress.yaml -n $NAMESPACE

# Step 7: Show status
echo "📊 Deployment status:"
kubectl get pods -n $NAMESPACE
kubectl get svc -n $NAMESPACE
kubectl get hpa -n $NAMESPACE
kubectl get ingress -n $NAMESPACE

# Final Info
echo "✅ Deployment completed successfully!"
echo "🌐 Access your services at:"
echo "   Frontend: https://nlq-ui.shop"
echo "   Backend API: https://api.avirat-empire.shop"
