#!/bin/bash

echo "🔧 Debezium Troubleshooting Script"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if services are running
print_status "Checking if required services are running..."

if ! docker ps | grep -q "kafka-connect"; then
    print_error "Kafka Connect is not running!"
    exit 1
fi

if ! docker ps | grep -q "postgres-db"; then
    print_error "PostgreSQL is not running!"
    exit 1
fi

if ! docker ps | grep -q "kafka"; then
    print_error "Kafka is not running!"
    exit 1
fi

print_success "All required services are running"

# Check Kafka Connect health
print_status "Checking Kafka Connect health..."
CONNECT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8086/)

if [ "$CONNECT_STATUS" != "200" ]; then
    print_error "Kafka Connect is not responding (HTTP $CONNECT_STATUS)"
    print_status "Checking Kafka Connect logs..."
    docker compose logs --tail 20 kafka-connect
    exit 1
fi

print_success "Kafka Connect is healthy"

# Check database connection and publication
print_status "Checking database setup..."

# Check if publication exists
PUB_EXISTS=$(docker exec postgres-db psql -U postgres -d outbox -t -c "SELECT COUNT(*) FROM pg_publication WHERE pubname='dbz_outbox_publication';" 2>/dev/null | tr -d ' ')

if [ "$PUB_EXISTS" = "1" ]; then
    print_success "Publication 'dbz_outbox_publication' exists"
else
    print_warning "Publication 'dbz_outbox_publication' not found, creating..."
    docker exec postgres-db psql -U postgres -d outbox -c "CREATE PUBLICATION dbz_outbox_publication FOR TABLE outbox;" 2>/dev/null
    print_success "Publication created"
fi

# Check if table exists
TABLE_EXISTS=$(docker exec postgres-db psql -U postgres -d outbox -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name='outbox';" 2>/dev/null | tr -d ' ')

if [ "$TABLE_EXISTS" = "1" ]; then
    print_success "Outbox table exists"
else
    print_error "Outbox table not found!"
    exit 1
fi

# Remove existing connector if it exists
print_status "Cleaning up existing connector..."
curl -s -X DELETE http://localhost:8086/connectors/outbox-postgres-connector > /dev/null 2>&1
sleep 3

# Remove existing replication slot if it exists
print_status "Cleaning up replication slot..."
docker exec postgres-db psql -U postgres -d outbox -c "SELECT pg_drop_replication_slot('debezium_outbox');" 2>/dev/null || true

# Deploy the connector
print_status "Deploying Debezium connector..."

CONNECTOR_CONFIG='{
  "name": "outbox-postgres-connector",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "postgres-db",
    "database.port": "5432",
    "database.user": "postgres",
    "database.password": "gerges1020",
    "database.dbname": "outbox",
    "database.server.name": "outbox",
    "topic.prefix": "outbox",
    "schema.include.list": "public",
    "table.include.list": "public.outbox",
    "plugin.name": "pgoutput",
    "slot.name": "debezium_outbox",
    "publication.name": "dbz_outbox_publication",
    "publication.autocreate.mode": "disabled",
    "snapshot.mode": "initial",
    "key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "key.converter.schemas.enable": "false",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false",
    "transforms": "unwrap,route",
    "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState",
    "transforms.unwrap.drop.tombstones": "false",
    "transforms.route.type": "org.apache.kafka.connect.transforms.RegexRouter",
    "transforms.route.regex": "outbox.public.outbox",
    "transforms.route.replacement": "user-events"
  }
}'

DEPLOY_RESULT=$(curl -s -X POST -H "Content-Type: application/json" -d "$CONNECTOR_CONFIG" http://localhost:8086/connectors)

if echo "$DEPLOY_RESULT" | grep -q "error"; then
    print_error "Failed to deploy connector:"
    echo "$DEPLOY_RESULT" | jq '.' 2>/dev/null || echo "$DEPLOY_RESULT"
    exit 1
fi

print_success "Connector deployed successfully"

# Wait for connector to start
print_status "Waiting for connector to start..."
sleep 5

# Check connector status
print_status "Checking connector status..."
STATUS=$(curl -s http://localhost:8086/connectors/outbox-postgres-connector/status)

if echo "$STATUS" | grep -q '"state":"RUNNING"'; then
    print_success "Connector is running!"
else
    print_error "Connector is not running:"
    echo "$STATUS" | jq '.' 2>/dev/null || echo "$STATUS"
    
    print_status "Checking connector logs..."
    docker compose logs --tail 10 kafka-connect
    exit 1
fi

# Test data insertion
print_status "Testing data flow..."
docker exec postgres-db psql -U postgres -d outbox -c "INSERT INTO outbox (sum, sent_at) VALUES (999, NULL);" > /dev/null

print_status "Waiting for message to propagate..."
sleep 3

# Check if topics were created
print_status "Checking created topics..."
TOPICS=$(docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 2>/dev/null)
echo "$TOPICS"

if echo "$TOPICS" | grep -q "user-events"; then
    print_success "user-events topic created"
else
    print_warning "user-events topic not found"
fi

if echo "$TOPICS" | grep -q "outbox.public.outbox"; then
    print_success "outbox.public.outbox topic created"
else
    print_warning "outbox.public.outbox topic not found"
fi

# Final status
print_status "Final connector status:"
curl -s http://localhost:8086/connectors/outbox-postgres-connector/status | jq '.'

print_success "Debezium troubleshooting complete!"
print_status "To test message flow:"
print_status "  1. Insert data: make test-sum-insert"
print_status "  2. Check topics: make list-topics"
print_status "  3. Monitor messages: make check-user-events-topic"