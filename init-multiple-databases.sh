#!/bin/bash
set -e

# Create multiple databases
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE outbox;
    CREATE DATABASE outbox_write;
    CREATE DATABASE outbox_read;
EOSQL

echo "Multiple databases created successfully!"

# Create outbox table in the outbox database
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "outbox" <<-EOSQL
    -- Create pgcrypto extension first for UUID generation
    CREATE EXTENSION IF NOT EXISTS pgcrypto;

    CREATE TABLE IF NOT EXISTS outbox (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        SUM INT NOT NULL,
        sent_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT NOW()
    );

    CREATE INDEX IF NOT EXISTS idx_outbox_sent_at ON outbox (sent_at);

    -- Create publication AFTER table creation
    CREATE PUBLICATION IF NOT EXISTS dbz_outbox_publication FOR TABLE outbox;

    GRANT SELECT ON outbox TO $POSTGRES_USER;
    GRANT USAGE, CREATE ON SCHEMA public TO $POSTGRES_USER;
EOSQL

echo "Table and publication created in outbox database!"

# Create tables in outbox_write database
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "outbox_write" <<-EOSQL
    CREATE TABLE IF NOT EXISTS outbox (
        id BIGINT PRIMARY KEY,
        sum INT NOT NULL DEFAULT 0
    );
    
    CREATE INDEX IF NOT EXISTS idx_outbox_sum ON outbox (sum);
    INSERT INTO outbox (id, sum) VALUES (1, 0) ON CONFLICT (id) DO NOTHING;
EOSQL

echo "Table created in outbox_write database!"

# Create tables in outbox_read database
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "outbox_read" <<-EOSQL
    CREATE TABLE IF NOT EXISTS outbox (
        id BIGINT PRIMARY KEY,
        sum INT NOT NULL DEFAULT 0
    );
    
    CREATE INDEX IF NOT EXISTS idx_outbox_sum ON outbox (sum);
    INSERT INTO outbox (id, sum) VALUES (1, 0) ON CONFLICT (id) DO NOTHING;
EOSQL

echo "Table created in outbox_read database!"