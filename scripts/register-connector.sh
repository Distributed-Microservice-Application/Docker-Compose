#!/bin/bash
# Script to register the Debezium connector with Kafka Connect

echo "Waiting for Kafka Connect to start..."
sleep 30  # Wait for Kafka Connect to be fully up and running

# Register the Debezium connector
echo "Registering Debezium connector..."
curl -X POST -H "Content-Type: application/json" --data @/etc/kafka-connect/connectors/outbox-connector.json http://kafka-connect:8083/connectors

echo "Connector registration attempt complete"

# Check if the connector was registered successfully
sleep 5
echo "Checking connector status..."
curl -s http://kafka-connect:8083/connectors

echo "Done!"
