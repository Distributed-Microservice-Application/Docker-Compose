.PHONY: help start stop create-topic list-topics test-connection logs-all logs-service-a logs-service-a-1 logs-service-a-2 logs-service-a-3 logs-service-b logs-infrastructure clean-images clean-all clean-build rebuild size-check fix-debezium connect-db delete-all-topics setup-debezium check-debezium deploy-connector remove-connector test-sum-insert check-sum-topic check-user-events-topic update-sum test-workflow logs-kafka-connector

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

start: ## Start Kafka and Zookeeper using Docker Compose
	docker compose up -d
	@echo "Waiting for Kafka to be ready..."
	@sleep 10
	@echo "Kafka is ready!"

stop: ## Stop Kafka and Zookeeper
	docker compose down

create-topic: ## Create the user-events topic
	docker exec kafka kafka-topics --create \
		--topic user-events \
		--bootstrap-server localhost:9092 \
		--replication-factor 1 \
		--partitions 3 \
		--if-not-exists

list-topics: ## List all Kafka topics
	docker exec kafka kafka-topics --list --bootstrap-server localhost:9092

test-connection: ## Test Kafka connection
	docker exec kafka kafka-broker-api-versions --bootstrap-server localhost:9092

# Debezium Management
setup-debezium: ## Complete Debezium setup (remove old, deploy new)
	@echo "Setting up Debezium connector..."
	-curl -X DELETE http://localhost:8086/connectors/outbox-postgres-connector 2>/dev/null || true
	@sleep 5
	@echo "Deploying new connector..."
	curl -X POST \
		-H "Content-Type: application/json" \
		--data @kafka-connect/connectors/outbox-connector.json \
		http://localhost:8086/connectors
	@echo "Connector deployed!"

deploy-connector: ## Deploy the Debezium connector
	curl -X POST \
		-H "Content-Type: application/json" \
		--data @kafka-connect/connectors/outbox-connector.json \
		http://localhost:8086/connectors

remove-connector: ## Remove the Debezium connector
	curl -X DELETE http://localhost:8086/connectors/outbox-postgres-connector

check-debezium: ## Check Debezium connector status
	@echo "=== Connector Status ==="
	@{ curl -s http://localhost:8086/connectors/outbox-postgres-connector/status || echo "Connector not found"; }
	@echo ""
	@echo "=== All Connectors ==="
	@curl -s http://localhost:8086/connectors
	@echo ""
	@echo "=== Database Publication ==="
	docker exec postgres-db psql -U postgres -d outbox -c "SELECT * FROM pg_publication;"
	@echo ""
	@echo "=== Replication Slots ==="
	docker exec postgres-db psql -U postgres -d outbox -c "SELECT * FROM pg_replication_slots;"

# Log viewing targets
logs-all: ## Show logs for all application services
	@echo "=== Service A-1 Logs ==="
	docker compose logs --tail 10 service-a-1
	@echo "=== Service A-2 Logs ==="
	docker compose logs --tail 10 service-a-2
	@echo "=== Service A-3 Logs ==="
	docker compose logs --tail 10 service-a-3
	@echo "=== Service B Logs ==="
	docker compose logs --tail 10 service-b

logs-service-a: ## Show logs for all Service A instances
	@echo "=== Service A-1 Logs ==="
	docker compose logs --tail 10 service-a-1
	@echo "=== Service A-2 Logs ==="
	docker compose logs --tail 10 service-a-2
	@echo "=== Service A-3 Logs ==="
	docker compose logs --tail 10 service-a-3

logs-service-a-1: ## Show logs for Service A instance 1
	docker compose logs --tail 20 -f service-a-1

logs-service-a-2: ## Show logs for Service A instance 2
	docker compose logs --tail 20 -f service-a-2

logs-service-a-3: ## Show logs for Service A instance 3
	docker compose logs --tail 20 -f service-a-3

logs-service-b: ## Show logs for Service B
	docker compose logs --tail 20 -f service-b

logs-kafka-connector: ## Show logs for Kafka Connect
	docker compose logs --tail 20 -f kafka-connect

logs-infrastructure: ## Show logs for infrastructure services
	@echo "=== Kafka Logs ==="
	docker compose logs --tail 10 kafka
	@echo "=== Postgres Logs ==="
	docker compose logs --tail 10 postgres
	@echo "=== Nginx Logs ==="
	docker compose logs --tail 10 nginx
	@echo "=== Kafka Connect Logs ==="
	docker compose logs --tail 15 kafka-connect

logs-kafka-connect: ## Show Kafka Connect logs
	docker compose logs --tail 50 -f kafka-connect

# Docker cleanup targets
clean-images: ## Remove unused Docker images
	@echo "Cleaning up unused Docker images..."
	docker image prune -f
	@echo "Cleanup complete!"

clean-all: ## Clean up all unused Docker resources
	@echo "Cleaning up all unused Docker resources..."
	docker system prune -f --volumes
	@echo "Cleanup complete!"

clean-build: ## Remove build cache
	@echo "Cleaning Docker build cache..."
	docker builder prune -f
	@echo "Build cache cleanup complete!"

rebuild: ## Stop, clean, and rebuild all services
	docker compose down
	docker system prune -f
	docker compose build --no-cache
	docker compose up -d
	@echo "Rebuild complete!"

size-check: ## Check Docker resource usage
	@echo "=== Docker Images Size ==="
	docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
	@echo ""
	@echo "=== Docker System Usage ==="
	docker system df

fix-debezium: ## Troubleshoot and fix Debezium CDC issues
	@echo "Starting Debezium troubleshooter..."
	chmod +x ./fix-debezium.sh
	./fix-debezium.sh

connect-db: ## Connect to Postgres database
	@echo "Connecting to Postgres database..."
	docker exec -it postgres-db psql -U postgres

delete-all-topics: ## Delete all Kafka topics
	@echo "Deleting all Kafka topics..."
	docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 | xargs -I {} docker exec kafka kafka-topics --delete --topic {} --bootstrap-server localhost:9092
	@echo "All topics deleted."

# Testing commands
test-sum-insert: ## Insert test sum data
	docker exec postgres-db psql -U postgres -d outbox -c "INSERT INTO outbox (sum, sent_at) VALUES (42, NULL);"

check-sum-topic: ## Check the outbox topic for sum changes
	docker exec kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic outbox.public.outbox --from-beginning --max-messages 5

check-user-events-topic: ## Check the user-events topic
	docker exec kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic user-events --from-beginning --max-messages 5

update-sum: ## Update a sum value to test CDC
	docker exec postgres-db psql -U postgres -d outbox -c "UPDATE outbox SET sum = sum + 10, sent_at = NOW() WHERE id = (SELECT id FROM outbox ORDER BY created_at DESC LIMIT 1);"

# Complete test workflow
test-workflow: ## Complete test workflow for Debezium
	@echo "=== Starting Debezium Test Workflow ==="
	@echo "1. Checking connector status..."
	@make check-debezium
	@echo ""
	@echo "2. Inserting test data..."
	@make test-sum-insert
	@echo ""
	@echo "3. Checking topics..."
	@make list-topics
	@echo ""
	@echo "4. Checking for messages in user-events topic..."
	@make check-user-events-topic
	@echo ""
	@echo "5. Updating sum to trigger CDC..."
	@make update-sum
	@echo ""
	@echo "Test workflow complete!"
