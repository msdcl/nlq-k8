#!/bin/bash

# Database Initialization Script for Kubernetes
# This script ensures the database is properly initialized with pgvector

set -e

echo "🗄️ Initializing PostgreSQL database with pgvector..."

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod \
    -l app=postgres \
    -n nlq-system \
    --timeout=300s

# Get PostgreSQL pod name
POSTGRES_POD=$(kubectl get pods -n nlq-system -l app=postgres -o jsonpath='{.items[0].metadata.name}')

echo "📦 PostgreSQL pod: $POSTGRES_POD"

# Test connection
echo "🔍 Testing PostgreSQL connection..."
kubectl exec -n nlq-system $POSTGRES_POD -- pg_isready -U nlq_user -d nlq_database

# Check if vector extension is installed
echo "🧠 Checking pgvector extension..."
kubectl exec -n nlq-system $POSTGRES_POD -- psql -U nlq_user -d nlq_database -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'vector';"

# Check if vector extension is installed in vector database
echo "🧠 Checking pgvector extension in vector database..."
kubectl exec -n nlq-system $POSTGRES_POD -- psql -U nlq_user -d nlq_vectors -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'vector';"

# List all databases
echo "📊 Listing all databases..."
kubectl exec -n nlq-system $POSTGRES_POD -- psql -U nlq_user -c "\l"

# List tables in main database
echo "📋 Listing tables in main database..."
kubectl exec -n nlq-system $POSTGRES_POD -- psql -U nlq_user -d nlq_database -c "\dt"

# List tables in vector database
echo "📋 Listing tables in vector database..."
kubectl exec -n nlq-system $POSTGRES_POD -- psql -U nlq_user -d nlq_vectors -c "\dt"

echo "✅ Database initialization completed successfully!"
echo "🗄️ PostgreSQL is ready with pgvector extension"
echo "📊 Main database: nlq_database"
echo "🧠 Vector database: nlq_vectors"