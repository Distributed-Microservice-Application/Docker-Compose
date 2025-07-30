.PHONY: help start stop create-topic list-topics test-connection logs-all logs-service-a logs-service-a-1 logs-service-a-2 logs-service-a-3 logs-service-b logs-infrastructure clean-images clean-all clean-build rebuild size-check

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

logs-infrastructure: ## Show logs for infrastructure services
	@echo "=== Kafka Logs ==="
	docker compose logs --tail 10 kafka
	@echo "=== Postgres Logs ==="
	docker compose logs --tail 10 postgres
	@echo "=== Nginx Logs ==="
	docker compose logs --tail 10 nginx

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