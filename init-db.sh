#!/bin/bash

# Database initialization script for NLQ application
# This script creates the necessary tables and extensions

set -e

echo "🗄️ Initializing NLQ Database..."

# Wait for PostgreSQL to be ready
until pg_isready -h postgres-service -p 5432 -U nlq_user; do
  echo "Waiting for PostgreSQL to be ready..."
  sleep 2
done

echo "✅ PostgreSQL is ready!"

# Create database extensions
echo "📦 Creating database extensions..."
psql -h postgres-service -p 5432 -U nlq_user -d nlq_database -c "CREATE EXTENSION IF NOT EXISTS vector;"
psql -h postgres-service -p 5432 -U nlq_user -d nlq_database -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"

echo "✅ Database extensions created!"

# Create basic tables (you can add your actual schema here)
echo "🏗️ Creating basic tables..."
psql -h postgres-service -p 5432 -U nlq_user -d nlq_database << EOF
-- Create table_metadata table for vector search
CREATE TABLE IF NOT EXISTS table_metadata (
    id SERIAL PRIMARY KEY,
    table_name VARCHAR(255) NOT NULL,
    description TEXT,
    schema_info JSONB,
    embedding vector(768),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_table_metadata_table_name ON table_metadata(table_name);
CREATE INDEX IF NOT EXISTS idx_table_metadata_embedding ON table_metadata USING ivfflat (embedding vector_cosine_ops);

-- Insert sample data (optional)
INSERT INTO table_metadata (table_name, description, schema_info) VALUES 
('customers', 'Customer information table', '{"columns": [{"name": "id", "type": "integer"}, {"name": "name", "type": "varchar"}, {"name": "email", "type": "varchar"}]}'),
('orders', 'Order information table', '{"columns": [{"name": "id", "type": "integer"}, {"name": "customer_id", "type": "integer"}, {"name": "total", "type": "decimal"}]}'),
('products', 'Product catalog table', '{"columns": [{"name": "id", "type": "integer"}, {"name": "name", "type": "varchar"}, {"name": "price", "type": "decimal"}]}')
ON CONFLICT DO NOTHING;

EOF

echo "✅ Database initialization completed!"
echo "🎉 NLQ database is ready to use!"
